// The Desktop and its sandbox manager need a typed IPC boundary; backend plugins
// cannot launch host sandboxes or select the Desktop's target server.
import { Schema } from "effect";
import { Ipc } from "../sdk";

export const Project = Schema.Struct({
  id: Schema.String,
  directory: Schema.String,
  name: Schema.String,
});

const Http = Schema.Struct({ url: Schema.String, password: Schema.String });
const Id = Schema.Struct({ id: Schema.String });

export const Sandbox = Ipc.define({
  id: "sandbox",
  state: Schema.Struct({
    revision: Schema.Number,
    servers: Schema.Array(Schema.Struct({
      ...Project.fields,
      state: Schema.Literals(["stopped", "starting", "ready", "failed"]),
      http: Schema.optional(Http),
    })),
  }),
  methods: {
    // Directory selection happens in trusted main-process code, never in a tool.
    open: { output: Schema.NullOr(Schema.Struct({ id: Schema.String, revision: Schema.Number })) },
    resolve: { input: Id, output: Schema.Struct({ ...Http.fields, revision: Schema.Number }) },
    reconnect: { input: Id, output: Http },
    stop: { input: Id },
    forget: { input: Id },
  },
});
