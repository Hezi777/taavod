export const coachOpenEvent = "career-helper:open-coach";
export type CoachOpenRequest = { expanded?: boolean; newConversation?: boolean; prompt?: string; type?: string; id?: string };

export function openCareerCoach(request: CoachOpenRequest = {}) {
  window.dispatchEvent(new CustomEvent(coachOpenEvent, { detail: request }));
}
