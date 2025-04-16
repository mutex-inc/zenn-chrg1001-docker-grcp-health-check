import type { ConnectRouter } from "@connectrpc/connect";
import { fastifyConnectPlugin } from "@connectrpc/connect-fastify";
import { create } from "@bufbuild/protobuf";
import fastify from "fastify";
import {
  Health,
  HealthCheckResponseSchema,
  HealthCheckResponse_ServingStatus,
} from "./gen/proto/grpc/health/v1/check_pb";

const healthRoutes = (router: ConnectRouter) => {
  router.service(Health, {
    check: async (_, __) => {
      console.info(`${new Date().toISOString()} - Health check called`);
      return create(HealthCheckResponseSchema, {
        status: HealthCheckResponse_ServingStatus.SERVING,
      });
    },
    watch: async function* (_, __) {
      console.info(`${new Date().toISOString()} - Health watch called`);
      while (true) {
        const response = create(HealthCheckResponseSchema, {
          status: HealthCheckResponse_ServingStatus.SERVING,
        });
        yield response;

        // ステータスチェックの間隔を設定
        await new Promise((resolve) => setTimeout(resolve, 1000));
      }
    },
  });
};

(async () => {
  const server = fastify({
    http2: true,
  });

  await server.register(fastifyConnectPlugin, {
    routes: healthRoutes,
  });

  await server.listen({
    host: "0.0.0.0",
    port: 8080,
  });

  process.once("SIGINT", async () => {
    await server.close();
  });

  process.once("SIGTERM", async () => {
    await server.close();
  });
})();
