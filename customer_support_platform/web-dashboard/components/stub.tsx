import { Construction } from "lucide-react";
import { PageHeader } from "@/components/page-header";
import { Panel, EmptyState } from "@/components/ui";

export function Stub({ title, note }: { title: string; note?: string }) {
  return (
    <>
      <PageHeader title={title} />
      <Panel>
        <EmptyState
          icon={<Construction size={22} />}
          title="Coming up next"
          body={note ?? "This screen is part of the current build pass."}
        />
      </Panel>
    </>
  );
}
