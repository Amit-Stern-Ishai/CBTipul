import { he } from "../he";
import { Link, useParams } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import { BookOpen } from "lucide-react";
import { api } from "../data/api";
import { useAuth } from "../auth/Auth";
import {
  Heading,
  Loading,
  ErrorBox,
  Empty,
  date,
  ClinicalContent,
} from "./shared";
import { AssignmentControl, PatientBreadcrumb } from "./Patients";
import { useReadOnDisplay } from "./App";
import type { ToolType } from "../domain/types";
function useDiary(id: string, n: number) {
  const { session } = useAuth();
  return useQuery({
    queryKey: [session!.user.id, "diaries", id, n],
    queryFn: () => api.diaries(id, n - 1),
    enabled: [1, 2, 3].includes(n),
  });
}
export function DiariesPage() {
  const { patientId: id = "", diary = "1" } = useParams();
  const n = Number(diary),
    rows = useDiary(id, n);
  if (![1, 2, 3].includes(n)) return <Empty>{he.Diaries001}</Empty>;
  return (
    <>
      <PatientBreadcrumb id={id} title={he.Diaries002(n)} />
      <Heading
        title={he.Diaries003(n)}
        description={
          n === 1 ? he.Diaries004 : n === 2 ? he.Diaries005 : he.Diaries006
        }
      />
      <AssignmentControl id={id} type={`diary_${n}` as ToolType} />
      {rows.isPending ? (
        <Loading />
      ) : rows.isError ? (
        <ErrorBox error={rows.error} retry={() => void rows.refetch()} />
      ) : rows.data.length ? (
        <div className="list panel">
          {rows.data.map((d) => (
            <Link
              className="list-row"
              to={`/patients/${id}/diaries/${n}/${d.id}`}
              key={d.id}
            >
              <span className="icon-tile">
                <BookOpen />
              </span>
              <div>
                <strong>{date(d.created_at)}</strong>
                <p>
                  {d.created_by === "patient" ? he.Diaries007 : he.Diaries008}
                </p>
                <p className="clamp">{d.event ?? d.situation}</p>
              </div>
            </Link>
          ))}
        </div>
      ) : (
        <Empty>{he.Diaries009}</Empty>
      )}
    </>
  );
}
export function DiaryDetail() {
  const { patientId: id = "", diary = "1", entryId = "" } = useParams();
  const n = Number(diary),
    rows = useDiary(id, n),
    entry = rows.data?.find((d) => d.id === entryId);
  useReadOnDisplay(!!entry);
  if (![1, 2, 3].includes(n)) return <Empty>{he.Diaries001}</Empty>;
  return (
    <>
      <PatientBreadcrumb id={id} title={he.Diaries010(n)} />
      {rows.isPending ? (
        <Loading />
      ) : rows.isError ? (
        <ErrorBox error={rows.error} />
      ) : !entry ? (
        <Empty>{he.Diaries011}</Empty>
      ) : (
        <>
          <Heading
            title={he.Diaries012(n)}
            description={he.Diaries013(
              date(entry.created_at),
              entry.created_by === "patient"
                ? "נכתב על ידי המטופל/ת"
                : "נכתב על ידי המטפל/ת",
            )}
          />
          <p className="small">{he.Diaries014}</p>
          {[
            [he.Diaries015, entry.event ?? entry.situation],
            [he.Diaries016, entry.automatic_thoughts],
            [he.Diaries017, entry.feelings],
            [he.Diaries018, entry.behaviour],
            [he.Diaries019, entry.physical_symptoms],
            [he.Diaries020, entry.thinking_errors],
            [he.Diaries021, entry.alternative_thoughts],
          ].map(
            ([title, value]) =>
              value && (
                <section className="panel" key={String(title)}>
                  <h2>{String(title)}</h2>
                  <ClinicalContent value={value} />
                </section>
              ),
          )}
        </>
      )}
    </>
  );
}
