"use client";

import { useMemo, useRef, useState } from "react";
import {
  BookOpen,
  Upload,
  FileText,
  Trash2,
  Archive,
  ArchiveRestore,
  CheckCircle2,
  CircleDashed,
  Search,
} from "lucide-react";
import { useAuth } from "@/lib/auth";
import {
  useKnowledgeDocs,
  useUploadKnowledge,
  useAddFaq,
  useDeleteKnowledge,
  useSetKnowledgeStatus,
} from "@/lib/queries";
import { useToast } from "@/components/toast";
import { PageHeader } from "@/components/page-header";
import {
  Panel,
  PanelHeader,
  Button,
  Input,
  Textarea,
  Field,
  Spinner,
  ErrorState,
  EmptyState,
  TableSkeleton,
  cn,
} from "@/components/ui";
import { relativeTime, titleCase } from "@/lib/format";

export default function KnowledgePage() {
  const { user } = useAuth();
  const isAdmin = user?.role === "admin";
  const docs = useKnowledgeDocs();
  const upload = useUploadKnowledge();
  const addFaq = useAddFaq();
  const del = useDeleteKnowledge();
  const setStatus = useSetKnowledgeStatus();
  const { notify } = useToast();

  const fileRef = useRef<HTMLInputElement>(null);
  const [uploadTitle, setUploadTitle] = useState("");
  const [faqOpen, setFaqOpen] = useState(false);
  const [q, setQ] = useState("");
  const [a, setA] = useState("");
  const [search, setSearch] = useState("");
  const [typeFilter, setTypeFilter] = useState<"" | "md" | "faq" | "pdf">("");

  const rows = useMemo(() => {
    let list = docs.data ?? [];
    if (typeFilter) list = list.filter((d) => d.file_type === typeFilter);
    if (search.trim()) {
      const n = search.toLowerCase();
      list = list.filter((d) => d.title.toLowerCase().includes(n));
    }
    return list;
  }, [docs.data, typeFilter, search]);

  async function onFile(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
    try {
      await upload.mutateAsync({ file, title: uploadTitle || undefined });
      notify(`"${file.name}" added to the knowledge base.`);
      setUploadTitle("");
    } catch (err) {
      notify((err as Error).message, "error");
    } finally {
      if (fileRef.current) fileRef.current.value = "";
    }
  }

  async function submitFaq() {
    if (!q.trim() || !a.trim()) return;
    try {
      await addFaq.mutateAsync({ question: q.trim(), answer: a.trim() });
      notify("FAQ added.");
      setQ("");
      setA("");
      setFaqOpen(false);
    } catch (err) {
      notify((err as Error).message, "error");
    }
  }

  return (
    <>
      <PageHeader
        title="Knowledge Base"
        subtitle="Documents and FAQs the AI assistant retrieves from"
        actions={
          isAdmin && (
            <>
              <Button variant="secondary" onClick={() => setFaqOpen((v) => !v)}>
                Add FAQ
              </Button>
              <Button
                variant="primary"
                onClick={() => fileRef.current?.click()}
                loading={upload.isPending}
              >
                <Upload size={14} /> Upload
              </Button>
              <input
                ref={fileRef}
                type="file"
                accept=".pdf,.txt,.md,.markdown"
                hidden
                onChange={onFile}
              />
            </>
          )
        }
      />

      {isAdmin && faqOpen && (
        <Panel className="mb-3 p-4">
          <p className="mb-3 text-[13px] font-semibold text-ink">New FAQ entry</p>
          <div className="flex flex-col gap-3">
            <Field label="Question">
              <Input
                value={q}
                onChange={(e) => setQ(e.target.value)}
                placeholder="How do I reset my password?"
              />
            </Field>
            <Field label="Answer">
              <Textarea
                rows={3}
                value={a}
                onChange={(e) => setA(e.target.value)}
                placeholder="Go to Settings → Security → Reset Password…"
              />
            </Field>
            <div className="flex justify-end gap-2">
              <Button variant="ghost" onClick={() => setFaqOpen(false)}>
                Cancel
              </Button>
              <Button
                variant="primary"
                onClick={submitFaq}
                loading={addFaq.isPending}
              >
                Save FAQ
              </Button>
            </div>
          </div>
        </Panel>
      )}

      {(docs.data ?? []).length > 0 && (
        <Panel className="mb-3 flex flex-wrap items-center gap-2 p-3">
          <div className="relative min-w-[220px] flex-1">
            <Search
              size={15}
              className="pointer-events-none absolute left-2.5 top-1/2 -translate-y-1/2 text-ink-faint"
            />
            <Input
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Search documents by title…"
              className="pl-8"
            />
          </div>
          <div className="flex gap-1">
            {(["", "md", "faq"] as const).map((t) => (
              <button
                key={t}
                onClick={() => setTypeFilter(t)}
                className={cn(
                  "rounded-md px-2.5 py-1.5 text-[12px] font-medium",
                  typeFilter === t
                    ? "bg-brand-wash text-brand"
                    : "text-ink-soft hover:bg-surface-2",
                )}
              >
                {t === "" ? "All" : t === "faq" ? "FAQ" : "Articles"}
              </button>
            ))}
          </div>
        </Panel>
      )}

      <Panel className="overflow-hidden">
        <PanelHeader
          title="Documents"
          subtitle={
            docs.data
              ? `${rows.length}${rows.length !== docs.data.length ? ` of ${docs.data.length}` : ""} entries`
              : undefined
          }
        />
        {docs.isLoading ? (
          <TableSkeleton rows={5} />
        ) : docs.isError ? (
          <ErrorState message={(docs.error as Error).message} />
        ) : (docs.data ?? []).length === 0 ? (
          <EmptyState
            icon={<BookOpen size={22} />}
            title="No knowledge yet"
            body={
              isAdmin
                ? "Upload a PDF, TXT or Markdown file, or add an FAQ, to give the AI something to retrieve from."
                : "An administrator hasn't added any documents yet."
            }
          />
        ) : rows.length === 0 ? (
          <EmptyState icon={<Search size={20} />} title="No documents match" />
        ) : (
          <div className="max-h-[70vh] divide-y divide-border overflow-y-auto scroll-thin">
            {rows.map((d) => (
              <div
                key={d.id}
                className="flex items-center gap-3 px-4 py-3"
              >
                <span className="grid size-9 shrink-0 place-content-center rounded-md bg-surface-2 text-ink-faint">
                  <FileText size={16} />
                </span>
                <div className="min-w-0 flex-1">
                  <p className="truncate text-[13px] font-medium text-ink">
                    {d.title}
                  </p>
                  <p className="text-[11.5px] text-ink-faint">
                    {d.file_type === "faq" ? "FAQ" : titleCase(d.file_type)} ·{" "}
                    {d.chunk_count} chunk{d.chunk_count === 1 ? "" : "s"} ·{" "}
                    {relativeTime(d.created_at)}
                  </p>
                </div>

                <span
                  className={cn(
                    "hidden items-center gap-1 rounded px-1.5 py-0.5 text-[11px] font-medium sm:inline-flex",
                    d.indexed
                      ? "bg-st-resolved-wash text-st-resolved"
                      : "bg-st-progress-wash text-st-progress",
                  )}
                  title={`${d.embedded_chunks}/${d.chunk_count} chunks embedded`}
                >
                  {d.indexed ? (
                    <CheckCircle2 size={11} />
                  ) : (
                    <CircleDashed size={11} />
                  )}
                  {d.indexed ? "Indexed" : "Not indexed"}
                </span>

                <span
                  className={cn(
                    "rounded px-1.5 py-0.5 text-[11px] font-medium",
                    d.status === "active"
                      ? "bg-brand-wash text-brand"
                      : "bg-st-closed-wash text-st-closed",
                  )}
                >
                  {titleCase(d.status)}
                </span>

                {isAdmin && (
                  <div className="flex items-center gap-1">
                    <button
                      onClick={() =>
                        setStatus.mutate({
                          id: d.id,
                          status: d.status === "active" ? "archived" : "active",
                        })
                      }
                      className="rounded p-1.5 text-ink-faint hover:bg-surface-2 hover:text-ink"
                      title={d.status === "active" ? "Archive" : "Restore"}
                    >
                      {d.status === "active" ? (
                        <Archive size={14} />
                      ) : (
                        <ArchiveRestore size={14} />
                      )}
                    </button>
                    <button
                      onClick={() => {
                        if (confirm(`Delete "${d.title}" from the knowledge base?`))
                          del.mutate(d.id, {
                            onSuccess: () => notify("Document deleted."),
                            onError: (e) =>
                              notify((e as Error).message, "error"),
                          });
                      }}
                      className="rounded p-1.5 text-ink-faint hover:bg-danger-wash hover:text-danger"
                      title="Delete"
                    >
                      <Trash2 size={14} />
                    </button>
                  </div>
                )}
              </div>
            ))}
          </div>
        )}
      </Panel>
    </>
  );
}
