/*
 * Copyright 2018 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

'use strict';

const logger = require('./logger')

if (process.env.DISABLE_PROFILER) {
  logger.info("Profiler disabled.")
} else {
  logger.info("Profiler enabled.")
  require('@google-cloud/profiler').start({
    serviceContext: {
      service: 'paymentservice',
      version: '1.0.0'
    }
  });
}


if (process.env.ENABLE_TRACING == "1") {
  logger.info("Tracing enabled.")

  const { resourceFromAttributes } = require('@opentelemetry/resources');

  const { ATTR_SERVICE_NAME }= require('@opentelemetry/semantic-conventions');

  const { GrpcInstrumentation } = require('@opentelemetry/instrumentation-grpc');
  const { registerInstrumentations } = require('@opentelemetry/instrumentation');
  const opentelemetry = require('@opentelemetry/sdk-node');

  const { OTLPTraceExporter } = require('@opentelemetry/exporter-otlp-grpc');

  const collectorUrl = process.env.COLLECTOR_SERVICE_ADDR;
  const traceExporter = new OTLPTraceExporter({url: collectorUrl});

  const sdk = new opentelemetry.NodeSDK({
    resource: resourceFromAttributes({
      [ATTR_SERVICE_NAME]: process.env.OTEL_SERVICE_NAME || 'paymentservice',
    }),
    traceExporter: traceExporter,
  });

  registerInstrumentations({
    instrumentations: [new GrpcInstrumentation()]
  });

  sdk.start()
} else {
  logger.info("Tracing disabled.")
}


const path = require('path');

if (process.env.WORKER_MODE === 'true') {
  const { ServiceBusClient } = require('@azure/service-bus');
  const { DefaultAzureCredential } = require('@azure/identity');
  const charge = require('./charge');

  const namespace    = process.env.SERVICEBUS_NAMESPACE || 'sre-sb-namespace';
  const topic        = process.env.SERVICEBUS_TOPIC || 'checkout-events';
  const subscription = process.env.SERVICEBUS_SUBSCRIPTION || 'payment';
  const fqns         = `${namespace}.servicebus.windows.net`;

  async function runWorker() {
    const credential = new DefaultAzureCredential();
    const client     = new ServiceBusClient(fqns, credential);
    const receiver   = client.createReceiver(topic, subscription);

    logger.info(`Payment worker started — ${fqns} topic=${topic} sub=${subscription}`);

    receiver.subscribe({
      processMessage: async (msg) => {
        try {
          const order = msg.body;
          logger.info(`Processing payment for order_id=${order.order_id} total=${order.total}`);
          charge({
            amount: { currency_code: 'USD', units: order.total || 0, nanos: 0 },
            credit_card: order.credit_card || {}
          });
          await receiver.completeMessage(msg);
          logger.info(`Payment completed for order_id=${order.order_id}`);
        } catch (err) {
          logger.warn(`Payment processing failed: ${err.message}`);
          await receiver.abandonMessage(msg);
        }
      },
      processError: async (args) => {
        logger.error(`Service Bus error: ${args.error}`);
      }
    });
  }

  runWorker().catch(err => { logger.error(err); process.exit(1); });

} else {
  const HipsterShopServer = require('./server');
  const PORT       = process.env['PORT'];
  const PROTO_PATH = path.join(__dirname, '/proto/');
  const server     = new HipsterShopServer(PROTO_PATH, PORT);
  server.listen();
}
