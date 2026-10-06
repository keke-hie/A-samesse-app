export {};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const allowedPlatforms = new Set([
  "instagram",
  "tiktok",
  "facebook",
  "whatsapp",
  "snapchat",
  "telegram",
  "x",
  "linkedin",
]);

const platformFormats: Record<string, string> = {
  instagram: "Légende concise, appel à l'action et hashtags pertinents. Proposer un visuel carré ou portrait 4:5.",
  tiktok: "Accroche immédiate, script vidéo vertical très court, texte à l'écran et légende.",
  facebook: "Publication accessible avec bénéfice produit, appel à l'action et visuel adapté au fil.",
  whatsapp: "Message commercial naturel et bref, adapté à une conversation ou à un statut vertical.",
  snapchat: "Texte très court et accrocheur pour une story verticale 9:16.",
  telegram: "Message de canal détaillé mais lisible, avec bénéfices, appel à l'action et lien à compléter.",
  x: "Publication très concise, directe et adaptée à la limite de caractères de X.",
  linkedin: "Publication professionnelle axée sur la valeur, le contexte et une conclusion claire.",
};

const platformAspectRatios: Record<string, string> = {
  instagram: "4:5",
  tiktok: "9:16",
  facebook: "4:3",
  whatsapp: "9:16",
  snapchat: "9:16",
  telegram: "4:3",
  x: "16:9",
  linkedin: "4:3",
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

denoRuntime.serve(async (request: Request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return jsonResponse({ error: "Méthode non autorisée." }, 405);

  const authorization = request.headers.get("Authorization");
  const supabaseUrl = denoRuntime.env.get("SUPABASE_URL");
  const supabaseAnonKey = denoRuntime.env.get("SUPABASE_ANON_KEY");
  const geminiApiKey = denoRuntime.env.get("GEMINI_API_KEY");

  if (!authorization || !supabaseUrl || !supabaseAnonKey) {
    return jsonResponse({ error: "Authentification Supabase requise." }, 401);
  }

  if (!geminiApiKey) {
    return jsonResponse({ error: "La clé Gemini n'est pas configurée côté serveur." }, 500);
  }

  try {
    const authResponse = await fetch(`${supabaseUrl}/auth/v1/user`, {
      headers: { apikey: supabaseAnonKey, Authorization: authorization },
    });
    if (!authResponse.ok) return jsonResponse({ error: "Session invalide." }, 401);
    const user = await authResponse.json();

    // Réservé aux vendeurs validés : chaque appel consomme le quota Gemini.
    const serviceRoleKey = denoRuntime.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!serviceRoleKey) {
      return jsonResponse({ error: "Le service marketing n'est pas configuré." }, 500);
    }
    const roleResponse = await fetch(
      `${supabaseUrl}/rest/v1/utilisateurs?id_utilisateur=eq.${encodeURIComponent(user.id)}&select=role,statut_compte`,
      { headers: { apikey: serviceRoleKey, Authorization: `Bearer ${serviceRoleKey}` } },
    );
    if (!roleResponse.ok) return jsonResponse({ error: "Vérification du rôle vendeur impossible." }, 500);
    const userRows = await roleResponse.json();
    if (userRows[0]?.role?.toString().toLowerCase() !== "vendeur") {
      return jsonResponse({ error: "Cette fonction est réservée aux vendeurs." }, 403);
    }
    if ((userRows[0]?.statut_compte ?? "actif") !== "actif") {
      return jsonResponse({ error: "Ton compte vendeur doit d'abord être validé." }, 403);
    }

    const body = await request.json();
    const productName = typeof body.productName === "string" ? body.productName.trim() : "";
    const description = typeof body.description === "string" ? body.description.trim() : "";
    const price = typeof body.price === "string" || typeof body.price === "number" ? String(body.price) : "";
    const creativeDirection = typeof body.creativeDirection === "string" ? body.creativeDirection.trim() : "";
    const productImageUrl = typeof body.productImageUrl === "string" ? body.productImageUrl : "";
    const platforms: string[] = Array.isArray(body.platforms)
      ? [...new Set<string>((body.platforms as unknown[]).filter((platform): platform is string => typeof platform === "string" && allowedPlatforms.has(platform)))]
      : [];
    const includeVisuals = body.includeVisuals === true;

    if (!productName || platforms.length === 0) {
      return jsonResponse({ error: "Indique un produit et au moins un réseau pris en charge." }, 400);
    }

    let productImageBase64 = "";
    let productImageMimeType = "image/jpeg";
    if (productImageUrl) {
      const imageUrl = new URL(productImageUrl);
      const projectUrl = new URL(supabaseUrl);
      if (imageUrl.host !== projectUrl.host || !imageUrl.pathname.startsWith("/storage/v1/object/public/images/")) {
        return jsonResponse({ error: "L'image de référence doit provenir du stockage public A'samesse." }, 400);
      }
      const imageResponse = await fetch(imageUrl);
      if (!imageResponse.ok) return jsonResponse({ error: "Lecture de la photo de référence impossible." }, 502);
      const imageBytes = new Uint8Array(await imageResponse.arrayBuffer());
      if (imageBytes.length > 9_000_000) return jsonResponse({ error: "La photo dépasse la limite de 9 Mo." }, 413);
      const mimeType = imageResponse.headers.get("content-type")?.split(";")[0];
      if (mimeType !== "image/jpeg" && mimeType !== "image/png" && mimeType !== "image/webp") {
        return jsonResponse({ error: "La photo doit être au format JPEG, PNG ou WebP." }, 415);
      }
      productImageMimeType = mimeType;
      productImageBase64 = btoa(Array.from(imageBytes, (byte) => String.fromCharCode(byte)).join(""));
    }

    const platformInstructions = platforms
      .map((platform: string) => `- ${platform}: ${platformFormats[platform]}`)
      .join("\n");

    const prompt = `Tu es un assistant marketing pour une boutique e-commerce francophone. Génère un contenu distinct pour chaque réseau demandé. Retourne uniquement un JSON valide sous la forme {"contents":[{"platform":"...","caption":"...","hashtags":["..."],"visual_prompt":"..."}]}. N'invente pas de caractéristiques produit non fournies. ${creativeDirection ? `Consigne de modification du vendeur: ${creativeDirection}` : ""} ${productImageBase64 ? "Utilise la photo jointe comme référence fidèle du produit." : ""}\n\nProduit: ${productName}\nDescription: ${description || "non fournie"}\nPrix: ${price || "non fourni"}\nRéseaux et consignes de format:\n${platformInstructions}`;
    const textParts: Array<Record<string, unknown>> = [{ text: prompt }];
    if (productImageBase64) {
      textParts.push({ inlineData: { mimeType: productImageMimeType, data: productImageBase64 } });
    }

    const geminiResponse = await fetch(
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-goog-api-key": geminiApiKey,
        },
        body: JSON.stringify({
          contents: [{ role: "user", parts: textParts }],
          generationConfig: { responseMimeType: "application/json", temperature: 0.7 },
        }),
      },
    );

    if (!geminiResponse.ok) {
      console.error("Gemini request failed:", geminiResponse.status);
      return jsonResponse({ error: "Gemini n'a pas pu générer le contenu." }, 502);
    }

    const result = await geminiResponse.json();
    const generatedText = result.candidates?.[0]?.content?.parts
      ?.map((part: { text?: string }) => part.text ?? "")
      .join("")
      .trim();

    if (!generatedText) return jsonResponse({ error: "Gemini a renvoyé une réponse vide." }, 502);

    try {
      const generated = JSON.parse(generatedText);
      if (!Array.isArray(generated.contents)) {
        return jsonResponse({ error: "La réponse Gemini ne contient pas de publications valides." }, 502);
      }

      if (!includeVisuals) return jsonResponse(generated);

      const contents = await Promise.all(generated.contents.map(async (content: Record<string, unknown>) => {
        const platform = String(content.platform ?? "");
        if (!allowedPlatforms.has(platform)) return content;

        const imagePrompt = `Create a polished e-commerce campaign image for a francophone African marketplace. Product: ${productName}. Product details provided by seller: ${description || "none"}. Campaign concept: ${String(content.visual_prompt ?? "")} Use a clean professional composition, no text, no logos, and do not invent product details. Aspect ratio ${platformAspectRatios[platform]}.`;

        try {
          const imageResponse = await fetch("https://generativelanguage.googleapis.com/v1beta/interactions", {
            method: "POST",
            headers: { "Content-Type": "application/json", "x-goog-api-key": geminiApiKey },
            body: JSON.stringify({
              model: "gemini-3.1-flash-image",
              input: productImageBase64
                ? [
                    { type: "text", text: imagePrompt },
                    { type: "image", data: productImageBase64, mime_type: productImageMimeType },
                  ]
                : imagePrompt,
              response_format: {
                type: "image",
                mime_type: "image/jpeg",
                aspect_ratio: platformAspectRatios[platform],
                image_size: "1K",
              },
              store: false,
            }),
          });

          if (!imageResponse.ok) {
            console.error("Gemini image request failed:", imageResponse.status);
            return { ...content, image_error: "Le visuel n'a pas pu être généré." };
          }

          const imageResult = await imageResponse.json();
          const imageBlock = imageResult.steps
            ?.filter((step: { type?: string }) => step.type === "model_output")
            .flatMap((step: { content?: Array<Record<string, unknown>> }) => step.content ?? [])
            .find((block: Record<string, unknown>) => block.type === "image");

          if (typeof imageBlock?.data !== "string") {
            return { ...content, image_error: "Gemini n'a pas renvoyé de fichier image." };
          }

          const imagePath = `${user.id}/marketing/${crypto.randomUUID()}.jpg`;
          const encodedPath = imagePath.split("/").map(encodeURIComponent).join("/");
          const uploadResponse = await fetch(`${supabaseUrl}/storage/v1/object/images/${encodedPath}`, {
            method: "POST",
            headers: {
              apikey: serviceRoleKey,
              Authorization: `Bearer ${serviceRoleKey}`,
              "Content-Type": "image/jpeg",
              "x-upsert": "false",
            },
            body: Uint8Array.from(atob(imageBlock.data), (character) => character.charCodeAt(0)),
          });

          if (!uploadResponse.ok) {
            console.error("Generated image upload failed:", uploadResponse.status);
            return { ...content, image_error: "Le visuel n'a pas pu être enregistré." };
          }

          return {
            ...content,
            image_url: `${supabaseUrl}/storage/v1/object/public/images/${encodedPath}`,
          };
        } catch (error) {
          console.error("Image generation failed:", error);
          return { ...content, image_error: "Erreur pendant la génération du visuel." };
        }
      }));

      return jsonResponse({ contents });
    } catch {
      console.error("Gemini returned invalid JSON");
      return jsonResponse({ error: "La réponse Gemini n'était pas au format attendu." }, 502);
    }
  } catch (error) {
    console.error("Marketing generation failed:", error);
    return jsonResponse({ error: "Erreur pendant la génération du contenu." }, 500);
  }
});