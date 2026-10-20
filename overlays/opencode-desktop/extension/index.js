// Register as a built-in because released Desktop builds do not yet load
// third-party GUI renderer extensions. Saved paths contain no server credentials.
import { Schema } from "effect";
import { Extension, Store } from "../sdk";
import { Project, Sandbox } from "./contract.js";

export default Extension.define({
  id: "sandbox",
  os: ["linux"],
  provides: { sandbox: Sandbox },
  stores: { projects: Store.main(Schema.Array(Project), []) },
});
