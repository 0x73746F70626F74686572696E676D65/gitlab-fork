import { isNumeric } from '~/lib/utils/number_utils';
import { formatNumber, n__, __ } from '~/locale';
import { formatDate } from '~/lib/utils/datetime/date_format_utility';

function isIsoDateString(dateString) {
  // Matches an ISO date string in the format `2024-03-14T00:00:00.000`
  const isoDateRegex = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}$/;
  return isoDateRegex.test(dateString);
}

export function formatVisualizationValue(value) {
  if (isIsoDateString(value)) {
    return formatDate(value);
  }

  if (isNumeric(value)) {
    return formatNumber(parseInt(value, 10));
  }

  return value;
}

export function formatVisualizationTooltipTitle(title, params) {
  const value = params?.seriesData?.at(0)?.value?.at(0);

  if (isIsoDateString(value)) {
    const formattedDate = formatDate(value);
    return title.replace(value, formattedDate);
  }

  return title;
}

export const humanizeDisplayUnit = ({ unit, data = 0 }) => {
  switch (unit) {
    case 'days':
      return n__('day', 'days', data);
    case 'per_day':
      return __('/day');
    case 'percent':
      return '%';
    default:
      return unit;
  }
};
