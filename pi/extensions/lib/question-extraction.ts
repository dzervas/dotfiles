export interface MarkedQuestion {
	question: string;
	context?: string;
}

const QUESTION_MARKER = /^\s*❓\s*/u;
const RECOMMENDATION_MARKER = /^\s*➡️\s*/u;

function cleanLines(lines: string[]): string {
	return lines
		.join(" ")
		.replace(/\*\*/g, "")
		.replace(/\s+/g, " ")
		.trim();
}

/**
 * Extract questions that the assistant explicitly marked with ❓.
 *
 * A following ➡️ block is the assistant's recommendation, not the user's
 * answer. Preserve it as context without treating the question as resolved.
 * Unmarked prose is left to the LLM extractor.
 */
export function extractMarkedQuestions(text: string): MarkedQuestion[] {
	const questions: MarkedQuestion[] = [];
	let questionLines: string[] | null = null;
	let recommendationLines: string[] = [];
	let readingRecommendation = false;

	const flush = () => {
		if (!questionLines) return;

		const question = cleanLines(questionLines);
		const recommendation = cleanLines(recommendationLines);
		if (question) {
			questions.push({
				question,
				...(recommendation
					? { context: `Assistant recommendation: ${recommendation}` }
					: {}),
			});
		}

		questionLines = null;
		recommendationLines = [];
		readingRecommendation = false;
	};

	for (const line of text.split("\n")) {
		if (QUESTION_MARKER.test(line)) {
			flush();
			questionLines = [line.replace(QUESTION_MARKER, "")];
			continue;
		}

		if (!questionLines) continue;

		if (RECOMMENDATION_MARKER.test(line)) {
			readingRecommendation = true;
			recommendationLines.push(line.replace(RECOMMENDATION_MARKER, ""));
			continue;
		}

		if (readingRecommendation) {
			recommendationLines.push(line);
		} else {
			questionLines.push(line);
		}
	}

	flush();
	return questions;
}
