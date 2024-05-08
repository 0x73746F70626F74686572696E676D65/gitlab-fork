import { extractGraphqlAiData } from 'ee/analytics/dashboards/ai_impact/api';

describe('AI impact dashboard api', () => {
  describe('extractGraphqlAiData', () => {
    it('returns `-` and an empty tooltip when the payload is undefined', () => {
      expect(extractGraphqlAiData()).toEqual({
        code_suggestions_usage_rate: {
          identifier: 'code_suggestions_usage_rate',
          value: '-',
          tooltip: '',
        },
      });
    });

    it.each`
      codeSuggestionsContributorsCount | codeContributorsCount
      ${undefined}                     | ${10}
      ${5}                             | ${undefined}
    `(
      'returns `-` and an empty tooltip when a count is undefined – codeSuggestionsContributorsCount: $codeSuggestionsContributorsCount, codeContributorsCount: $codeContributorsCount',
      ({ codeSuggestionsContributorsCount, codeContributorsCount }) => {
        expect(
          extractGraphqlAiData({ codeSuggestionsContributorsCount, codeContributorsCount }),
        ).toEqual({
          code_suggestions_usage_rate: {
            identifier: 'code_suggestions_usage_rate',
            value: '-',
            tooltip: '',
          },
        });
      },
    );

    it('formats the value and tooltip for the table', () => {
      expect(
        extractGraphqlAiData({ codeSuggestionsContributorsCount: 5, codeContributorsCount: 10 }),
      ).toEqual({
        code_suggestions_usage_rate: {
          identifier: 'code_suggestions_usage_rate',
          value: 50,
          tooltip: '5/10',
        },
      });
    });

    it('has tooltip text when code contributors have not used code suggestions feature', () => {
      expect(
        extractGraphqlAiData({ codeSuggestionsContributorsCount: 0, codeContributorsCount: 12 }),
      ).toEqual({
        code_suggestions_usage_rate: {
          identifier: 'code_suggestions_usage_rate',
          value: 0,
          tooltip: '0/12',
        },
      });
    });
  });
});
