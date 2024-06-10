import { extractGraphqlAiData } from 'ee/analytics/dashboards/ai_impact/api';

describe('AI impact dashboard api', () => {
  describe('extractGraphqlAiData', () => {
    const buildResult = ({ value = '-', tooltip = 'No data' } = {}) => ({
      code_suggestions_usage_rate: {
        identifier: 'code_suggestions_usage_rate',
        value,
        tooltip,
      },
    });

    it('returns `-` and `No data` tooltip when the payload is undefined', () => {
      expect(extractGraphqlAiData()).toEqual(buildResult());
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
            codeSuggestionsContributorsCount,
            codeContributorsCount,
          }),
        ).toEqual(result);
      },
    );
  });
});
