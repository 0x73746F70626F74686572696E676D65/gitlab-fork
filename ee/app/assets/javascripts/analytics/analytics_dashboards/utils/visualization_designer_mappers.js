export function mapQueryToTokenValues(query) {
  const values = [];

  if (query?.measures?.length) {
    values.push(
      ...query.measures.map((measure) => ({
        type: 'measure',
        value: {
          data: measure,
          operator: '=',
        },
      })),
    );
  }

  return values;
}

export function mapTokenValuesToQuery(tokenValues, availableTokens) {
  const newQuery = {};

  const validMeasures = availableTokens.find((token) => token.type === 'measure').options;
  const selectedMeasures = tokenValues.filter((token) => token.type === 'measure');
  for (const measure of selectedMeasures) {
    const isValidMeasure = validMeasures.some((option) => option.value === measure.value.data);

    if (isValidMeasure) {
      newQuery.measures = newQuery.measures || [];
      newQuery.measures.push(measure.value.data);
    }
  }

  return newQuery;
}
