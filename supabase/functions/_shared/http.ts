import { ApiError } from "./payment_service.ts";

export type AuthenticatedHandler = (
  userId: string,
  body: Record<string, unknown>,
) => Promise<unknown>;

export interface Authenticator {
  getUserId(authorization: string): Promise<string | null>;
}

export function serveAuthenticated(
  authenticator: Authenticator,
  handler: AuthenticatedHandler,
): (request: Request) => Promise<Response> {
  return async (request) => {
    if (request.method === "OPTIONS") return response(null, 204);
    if (request.method !== "POST") return response({ error: "Method not allowed" }, 405);
    try {
      const authorization = request.headers.get("authorization") ?? "";
      const userId = await authenticator.getUserId(authorization);
      if (userId == null) throw new ApiError(401, "Authentication required");
      const body = await request.json().catch(() => ({})) as Record<string, unknown>;
      return response(await handler(userId, body), 200);
    } catch (error) {
      if (error instanceof ApiError) return response({ error: error.message }, error.status);
      console.error(error);
      return response({ error: "Internal server error" }, 500);
    }
  };
}

function response(body: unknown, status: number): Response {
  return new Response(body == null ? null : JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json",
      "access-control-allow-origin": "*",
      "access-control-allow-headers": "authorization, x-client-info, apikey, content-type",
    },
  });
}
