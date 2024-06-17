import { MEASURE, DIMENSION } from '../constants';

function getValidTokenValues(tokenValues, availableTokens, tokenType) {
  const validOptions = availableTokens.find((token) => token.type === tokenType)?.options;
  const selectedTokens = tokenValues.filter((token) => token.type === tokenType);

  const validSelectedTokens = selectedTokens.filter((token) =>
    validOptions.some((option) => option.value === token.value.data),
  );

  return validSelectedTokens.map((token) => token.value.data);
}

function createToken(type, value) {
  return {
    type,
    value: {
      data: value,
      operator: '=',
    },
  };
}

export function mapQueryToTokenValues(query) {
  const values = [];

  if (query?.measures?.length > 0) {
    values.push(...query.measures.map((m) => createToken(MEASURE, m)));
  }

  if (query?.dimensions?.length > 0) {
    values.push(...query.dimensions.map((d) => createToken(DIMENSION, d)));
  }

  return values;
}

export function mapTokenValuesToQuery(tokenValues, availableTokens) {
  const measures = getValidTokenValues(tokenValues, availableTokens, MEASURE);
  const dimensions = getValidTokenValues(tokenValues, availableTokens, DIMENSION);

  return {
    ...(measures.length > 0 && { measures }),
    ...(dimensions.length > 0 && { dimensions }),
  };
}
