import { describe, expect, it } from "vitest";
import { questionnaireScore } from "./scores";
import { createWorksheet, questionnaireFlags } from "./model";
describe("mobile questionnaire interpretation", () => {
  const answers = (count: number, total: number) => Array.from({ length: count }, (_, i) => Math.max(0, Math.min(3, total - i * 3)));
  it.each([[0,"ללא חרדה משמעותית"],[4,"ללא חרדה משמעותית"],[5,"חרדה קלה"],[9,"חרדה קלה"],[10,"חרדה משמעותית"],[14,"חרדה משמעותית"],[15,"חרדה קשה"],[21,"חרדה קשה"]])("GAD %s", (total, label) => { expect(questionnaireScore(answers(7, Number(total)), "gad")).toMatchObject({ total, label, answered: 7 }); });
  it.each([[0,"דיכאון מינימלי"],[4,"דיכאון מינימלי"],[5,"דיכאון קל"],[9,"דיכאון קל"],[10,"דיכאון בינוני"],[14,"דיכאון בינוני"],[15,"דיכאון בינוני כבד"],[19,"דיכאון בינוני כבד"],[20,"דיכאון כבד"],[27,"דיכאון כבד"]])("PHQ %s", (total, label) => { expect(questionnaireScore(answers(9, Number(total)), "phq")).toMatchObject({ total, label, answered: 9 }); });
  it("reports progress without interpreting missing/invalid answers and flags Q9 separately", () => {
    expect(questionnaireScore([0,1,null,null,null,null,null], "gad")).toMatchObject({ total: null, label: null, answered: 2 });
    expect(questionnaireScore([0,1,4,0,0,0,0], "gad").total).toBeNull();
    const item = createWorksheet("questionnaire"); item.data.phq9_answers = [null,null,null,null,null,null,null,null,1]; item.data.interference_level=3;
    expect(questionnaireFlags(item)).toMatchObject({ gad: null, phq: null, question9: true });
    item.data.gad7_answers=Array(7).fill(0); item.data.phq9_answers=Array(9).fill(0);
    expect(questionnaireFlags(item)).toMatchObject({ gad: 0, phq: 0, question9: false });
  });
});
