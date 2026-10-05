export {};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const denoRuntime = (globalThis as typeof globalThis & {
  Deno: {
    env: { get(name: string): string | undefined };
    serve(handler: (request: Request) => Response | Promise<Response>): void;
  };
}).Deno;

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function encodeBase64(bytes: Uint8Array): string {
  let binary = "";
  const chunkSize = 0x8000;
  for (let offset = 0; offset < bytes.length; offset += chunkSize) {
    binary += String.fromCharCode(...bytes.subarray(offset, offset + chunkSize));
  }
  return btoa(binary);
}

type StudioScene = "neutre" | "studio" | "dressing" | "mannequin";

const SCENES: Record<StudioScene, string> = {
  neutre: "un fond neutre et uni, très clair, sans texture, pour un rendu e-commerce épuré",
  studio:
    "un décor de studio professionnel clair et élégant, avec une lumière douce et un léger dégradé de fond",
  dressing:
    "un décor de dressing moderne et lumineux, aux teintes chaudes, avec un cadrage soigné",
  mannequin:
    "un mannequin virtuel invisible (effet buste), sans visage, sans ajouter d'accessoire absent de la photo",
};

function normalizeScene(value: unknown): StudioScene {
  const key = typeof value === "string" ? value.toLowerCase() : "";
  return (Object.prototype.hasOwnProperty.call(SCENES, key) ? key : "studio") as StudioScene;
}

function buildStudioPrompt(scene: StudioScene, productName: string, description: string): string {
  const decor = SCENES[scene];
  return `Retouche la photo produit fournie pour en faire une photographie e-commerce professionnelle. Supprime l'arrière-plan d'origine (détourage automatique). Garde exactement le même produit, sa forme, ses couleurs, ses matières, ses accessoires et ses détails reconnaissables. Place-le sur ${decor}. Améliore l'éclairage, la luminosité, les contrastes et la netteté pour un rendu photoréaliste. Produit : ${productName}. Description fiable fournie par le vendeur : ${description || "aucune"}. N'ajoute ni texte, ni logo, ni accessoire absent de la photo.`;
}

denoRuntime.serve(async (request: Request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return jsonResponse({ error: "Méthode non autorisée." }, 405);

  const authorization = request.headers.get("Authorization");
  const supabaseUrl = denoRuntime.env.get("SUPABASE_URL");
  const anonKey = denoRuntime.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = denoRuntime.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const geminiApiKey = denoRuntime.env.get("GEMINI_API_KEY");

  if (!authorization || !supabaseUrl || !anonKey) return jsonResponse({ error: "Connexion requise." }, 401);
  if (!serviceRoleKey || !geminiApiKey) return jsonResponse({ error: "Le service image n'est pas configuré." }, 500);

  try {
    const authResponse = await fetch(`${supabaseUrl}/auth/v1/user`, {
      headers: { apikey: anonKey, Authorization: authorization },
    });
    if (!authResponse.ok) return jsonResponse({ error: "Session invalide." }, 401);
    const user = await authResponse.json();

    const roleResponse = await fetch(
      `${supabaseUrl}/rest/v1/utilisateurs?id_utilisateur=eq.${encodeURIComponent(user.id)}&select=role`,
      { headers: { apikey: serviceRoleKey, Authorization: `Bearer ${serviceRoleKey}` } },
    );
    if (!roleResponse.ok) return jsonResponse({ error: "Vérification du rôle vendeur impossible." }, 500);
    const userRows = await roleResponse.json();
    if (userRows[0]?.role?.toString().toLowerCase() !== "vendeur") {
      return jsonResponse({ error: "Cette fonction est réservée aux vendeurs." }, 403);
    }

    const body = await request.json();
    let productName = typeof body.productName === "string" ? body.productName.trim() : "";
    let description = typeof body.description === "string" ? body.description.trim() : "";
    let imageBase64 = typeof body.imageBase64 === "string" ? body.imageBase64 : "";
    let mimeType = body.mimeType === "image/png" ? "image/png" : "image/jpeg";
    const productId = typeof body.productId === "string" ? body.productId : null;
    const restoreOriginal = body.restoreOriginal === true;
    const scene = normalizeScene(body.scene);

    let existingProduct: Record<string, unknown> | null = null;

    if (productId != null) {
      const productResponse = await fetch(
        `${supabaseUrl}/rest/v1/produits?id_produit=eq.${encodeURIComponent(productId)}&id_vendeur=eq.${encodeURIComponent(user.id)}&select=id_produit,nom_produit,description,image_url,image_originale_url`,
        { headers: { apikey: serviceRoleKey, Authorization: `Bearer ${serviceRoleKey}` } },
      );
      if (!productResponse.ok) return jsonResponse({ error: "Lecture du produit impossible." }, 502);
      const products = await productResponse.json();
      if (!Array.isArray(products) || products.length === 0) {
        return jsonResponse({ error: "Produit introuvable dans ta boutique." }, 404);
      }

      existingProduct = products[0];

      if (existingProduct == null) {
        return jsonResponse({ error: "Produit introuvable dans ta boutique." }, 404);
      }

      if (restoreOriginal) {
        const originalUrl = existingProduct.image_originale_url;
        if (typeof originalUrl !== "string" || originalUrl.length === 0) {
          return jsonResponse({ error: "Aucune photo originale conservée pour ce produit." }, 409);
        }
        const restoreResponse = await fetch(
          `${supabaseUrl}/rest/v1/produits?id_produit=eq.${encodeURIComponent(productId)}&id_vendeur=eq.${encodeURIComponent(user.id)}`,
          {
            method: "PATCH",
            headers: {
              apikey: serviceRoleKey,
              Authorization: `Bearer ${serviceRoleKey}`,
              "Content-Type": "application/json",
              Prefer: "return=minimal",
            },
            body: JSON.stringify({ image_url: originalUrl }),
          },
        );
        if (!restoreResponse.ok) return jsonResponse({ error: "Restauration de la photo originale impossible." }, 502);
        return jsonResponse({ image_url: originalUrl });
      }

      productName ||= String(existingProduct.nom_produit ?? "");
      description ||= String(existingProduct.description ?? "");

      const rawSourceUrl = String(existingProduct.image_originale_url ?? existingProduct.image_url ?? "");
      if (!rawSourceUrl) {
        return jsonResponse({ error: "Aucune photo du produit n'est disponible pour la retouche." }, 400);
      }

      const sourceUrl = new URL(rawSourceUrl);
      const projectHost = new URL(supabaseUrl).hostname;
      if (sourceUrl.hostname !== projectHost || !sourceUrl.pathname.startsWith("/storage/v1/object/public/images/")) {
        return jsonResponse({ error: "Cette photo ne vient pas du stockage produit A'samesse. Réimporte-la pour la retoucher." }, 400);
      }

      const sourceResponse = await fetch(sourceUrl);
      if (!sourceResponse.ok) return jsonResponse({ error: "Téléchargement de la photo produit impossible." }, 502);
      const sourceBytes = new Uint8Array(await sourceResponse.arrayBuffer());
      if (sourceBytes.length > 9_000_000) return jsonResponse({ error: "La photo source dépasse la limite de taille." }, 413);
      const sourceMimeType = sourceResponse.headers.get("content-type")?.split(";")[0];
      if (sourceMimeType !== "image/jpeg" && sourceMimeType !== "image/png") {
        return jsonResponse({ error: "La photo source doit être au format JPEG ou PNG." }, 415);
      }
      imageBase64 = encodeBase64(sourceBytes);
      mimeType = sourceMimeType;
    }

    if (!productName || !imageBase64) {
      return jsonResponse({ error: "Le nom du produit et sa photo sont obligatoires." }, 400);
    }
    if (imageBase64.length > 12_000_000) {
      return jsonResponse({ error: "La photo est trop volumineuse. Choisis une image plus légère." }, 413);
    }

    const prompt = buildStudioPrompt(scene, productName, description);

    const generateImage = async (aspectRatio: string): Promise<string | null> => {
      const imageResponse = await fetch("https://generativelanguage.googleapis.com/v1beta/interactions", {
        method: "POST",
        headers: { "Content-Type": "application/json", "x-goog-api-key": geminiApiKey },
        body: JSON.stringify({
          model: "gemini-3.1-flash-image",
          input: [
            { type: "text", text: prompt },
            { type: "image", data: imageBase64, mime_type: mimeType },
          ],
          response_format: {
            type: "image",
            mime_type: "image/jpeg",
            aspect_ratio: aspectRatio,
            image_size: "1K",
          },
          store: false,
        }),
      });

      if (!imageResponse.ok) {
        console.error(`Gemini product image request failed (${aspectRatio}):`, imageResponse.status);
        return null;
      }

      const result = await imageResponse.json();
      const imageBlock = result.steps
        ?.filter((step: { type?: string }) => step.type === "model_output")
        .flatMap((step: { content?: Array<Record<string, unknown>> }) => step.content ?? [])
        .find((block: Record<string, unknown>) => block.type === "image");

      return typeof imageBlock?.data === "string" ? imageBlock.data : null;
    };

    const squareBase64 = await generateImage("1:1");
    if (squareBase64 == null) {
      return jsonResponse({ error: "Gemini n'a pas pu retoucher cette photo. Réessaie avec une image nette du produit." }, 502);
    }
    const verticalBase64 = await generateImage("9:16");

    const uploadImage = async (path: string, base64: string): Promise<string | null> => {
      const encodedPath = path.split("/").map(encodeURIComponent).join("/");
      const imageBytes = Uint8Array.from(atob(base64), (character) => character.charCodeAt(0));
      const uploadResponse = await fetch(`${supabaseUrl}/storage/v1/object/images/${encodedPath}`, {
        method: "POST",
        headers: {
          apikey: serviceRoleKey,
          Authorization: `Bearer ${serviceRoleKey}`,
          "Content-Type": "image/jpeg",
          "x-upsert": "false",
        },
        body: imageBytes,
      });
      if (!uploadResponse.ok) return null;
      return `${supabaseUrl}/storage/v1/object/public/images/${encodedPath}`;
    };

    if (productId != null && existingProduct != null) {
      const timestamp = Date.now();
      const imageUrl = await uploadImage(`products/${user.id}/${productId}_studio_${timestamp}.jpg`, squareBase64);
      if (imageUrl == null) return jsonResponse({ error: "Enregistrement de la photo retouchée impossible." }, 502);

      const verticalUrl = verticalBase64 == null
        ? null
        : await uploadImage(`products/${user.id}/${productId}_story_${timestamp}.jpg`, verticalBase64);

      const updateResponse = await fetch(
        `${supabaseUrl}/rest/v1/produits?id_produit=eq.${encodeURIComponent(productId)}&id_vendeur=eq.${encodeURIComponent(user.id)}`,
        {
          method: "PATCH",
          headers: {
            apikey: serviceRoleKey,
            Authorization: `Bearer ${serviceRoleKey}`,
            "Content-Type": "application/json",
            Prefer: "return=minimal",
          },
          body: JSON.stringify({
            image_url: imageUrl,
            image_verticale_url: verticalUrl,
            image_originale_url: existingProduct.image_originale_url ?? existingProduct.image_url,
          }),
        },
      );
      if (!updateResponse.ok) return jsonResponse({ error: "La photo a été générée mais le produit n'a pas pu être mis à jour." }, 502);
      return jsonResponse({ image_url: imageUrl, image_verticale_url: verticalUrl, scene });
    }

    return jsonResponse({
      imageBase64: squareBase64,
      imageVerticalBase64: verticalBase64,
      mimeType: "image/jpeg",
      scene,
    });
  } catch (error) {
    console.error("Product image enhancement failed:", error);
    return jsonResponse({ error: "Erreur pendant la retouche de la photo." }, 500);
  }
});