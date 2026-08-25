import { serveAuthenticated } from "../_shared/http.ts";
import { createRuntime } from "../_shared/runtime.ts";

const runtime = createRuntime();
Deno.serve(serveAuthenticated(
  runtime.authenticator,
  (userId, body) => runtime.service.processTaskCompletion(userId, body.taskId),
));
