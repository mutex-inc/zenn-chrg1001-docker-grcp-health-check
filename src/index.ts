import type { ConnectRouter } from "@connectrpc/connect";
import { fastifyConnectPlugin } from "@connectrpc/connect-fastify";
import { create } from "@bufbuild/protobuf";
import fastify from "fastify";
import {
  CheckResponseSchema,
  ServingStatus,
} from "./gen/proto/grpc/health/v1/check_pb";
import { Health } from "./gen/proto/grpc/health/v1/service_pb";

const healthRoutes = (router: ConnectRouter) => {
  router.service(Health, {
    check: (_, __) => {
      console.info("check called");
      return create(CheckResponseSchema, {
        status: ServingStatus.SERVING,
      });
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
