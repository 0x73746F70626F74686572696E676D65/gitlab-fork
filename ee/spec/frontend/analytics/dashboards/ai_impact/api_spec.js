import { extractGraphqlAiData } from 'ee/analytics/dashboards/ai_impact/api';

describe('AI impact dashboard api', () => {
  describe('extractGraphqlAiData', () => {
    const timePeriodEnd = new Date('2024-05-05');
    const buildResult = ({ value = '-', tooltip = 'No data' } = {}) => ({
      code_suggestions_usage_rate: {
        identifier: 'code_suggestions_usage_rate',
        value,
        tooltip,
      },
    });

    it('returns `-` and `No data` tooltip when the payload is undefined', () => {
      expect(extractGraphqlAiData({ timePeriodEnd })).toEqual(buildResult());
    });

    it('has tooltip when `timePeriodEnd` is earlier than the code suggestions start date', () => {
      expect(
        extractGraphqlAiData({
          timePeriodEnd: new Date('2024-04-01'),
        }),
      ).toEqual({
        code_suggestions_usage_rate: {
          identifier: 'code_suggestions_usage_rate',
          value: '-',
          tooltip:
            'Usage rate for Code Suggestions is calculated with data starting on Apr 04, 2024',
        },
      });
    });

    it.each`
      codeSuggestionsContributorsCount | codeContributorsCount | result
      ${undefined}                     | ${5}                  | ${buildResult()}
      ${5}                             | ${undefined}          | ${buildResult()}
      ${5}                             | ${10}                 | ${buildResult({ value: 50, tooltip: '5/10' })}
      ${0}                             | ${12}                 | ${buildResult({ value: 0, tooltip: '0/12' })}
    `(
      'extracts correct data when codeSuggestionsContributorsCount: $codeSuggestionsContributorsCount and codeContributorsCount: $codeContributorsCount',
      ({ codeSuggestionsContributorsCount, codeContributorsCount, result }) => {
        expect(
          extractGraphqlAiData({
            timePeriodEnd,
            codeSuggestionsContributorsCount,
            codeContributorsCount,
          }),
        ).toEqual(result);
      },
    );
  });
});
