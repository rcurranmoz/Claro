const ANTHROPIC_API = "https://api.anthropic.com";

export default {
  async fetch(request, env) {
    // Only allow POST to /v1/messages
    if (request.method !== "POST") {
      return new Response("Method not allowed", { status: 405 });
    }
    const url = new URL(request.url);
    if (url.pathname !== "/v1/messages") {
      return new Response("Not found", { status: 404 });
    }

    // Validate app secret
    const secret = request.headers.get("X-Claro-Secret");
    if (!secret || secret !== env.CLARO_APP_SECRET) {
      return new Response("Unauthorized", { status: 401 });
    }

    // Forward to Anthropic, replacing auth header with stored key
    const body = await request.arrayBuffer();
    const upstream = await fetch(`${ANTHROPIC_API}/v1/messages`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": env.ANTHROPIC_API_KEY,
        "anthropic-version": request.headers.get("anthropic-version") || "2023-06-01",
      },
      body,
    });

    const responseBody = await upstream.arrayBuffer();
    return new Response(responseBody, {
      status: upstream.status,
      headers: { "Content-Type": "application/json" },
    });
  },
};
