// Native server-row parts are required: upstream does not show contributed
// menu actions or a reconnect button for entries without their own row.
import { Button } from "@opencode/ui/button";
import { Icon } from "@opencode/ui/icon";
import { IconButton } from "@opencode/ui/icon-button";
import { Menu } from "@opencode/ui/menu";
import { Show } from "solid-js";

export default function SandboxRow(props) {
  return (
    <Show when={props.entry()}>
      {(entry) => (
        <div class="settings-servers-row">
          <div class="settings-servers-lead">
            <props.row.Indicator
              health={entry().state === "failed" ? { healthy: false } : props.row.health()}
              connecting={entry().state === "starting"}
            />
            <div class="settings-servers-copy">
              <bdi class="settings-servers-name truncate" dir="auto">{entry().name}</bdi>
              <span class="settings-servers-meta">{entry().directory}</span>
            </div>
          </div>
          <div class="settings-servers-actions">
            <Button
              size="small"
              variant="ghost-muted"
              disabled={entry().state === "starting"}
              onClick={props.open}
            >
              Open project
            </Button>
            <Menu gutter={4} modal={false} placement="bottom-end">
              <Menu.Trigger
                as={IconButton}
                variant="ghost-muted"
                size="small"
                icon={<Icon name="outline-dots" />}
                aria-label="Sandbox options"
              />
              <Menu.Portal>
                <Menu.Content>
                  <Menu.Group>
                    <Menu.GroupLabel>Sandbox</Menu.GroupLabel>
                    <props.row.Items />
                    <Menu.Separator />
                    <Menu.Item onSelect={() => void props.row.remove()}>Remove server</Menu.Item>
                  </Menu.Group>
                </Menu.Content>
              </Menu.Portal>
            </Menu>
          </div>
        </div>
      )}
    </Show>
  );
}
