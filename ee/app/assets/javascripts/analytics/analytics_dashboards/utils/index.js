import { cloneWithoutReferences } from '~/lib/utils/common_utils';
import { humanize } from '~/lib/utils/text_utility';
import { getUniquePanelId } from 'ee/vue_shared/components/customizable_dashboard/utils';
import { SESSIONS_TABLE_NAME } from 'ee/analytics/analytics_dashboards/constants';
import { DATE_RANGE_FILTER_DIMENSIONS } from 'ee/analytics/analytics_dashboards/data_sources/cube_analytics';

export const createNewVisualizationPanel = (visualization) => ({
  id: getUniquePanelId(),
  title: humanize(visualization.slug),
  gridAttributes: {
    width: 4,
    height: 3,
  },
  queryOverrides: {},
  options: {},
  visualization: cloneWithoutReferences({ ...visualization, errors: null }),
});

/**
 * Given a CubeJS property (e.g. `Sessions.count`), get the schema name (e.g. `Sessions`).
 */
export function getMetricSchema(metric) {
  return metric?.split('.')[0];
}

/**
 * Filters an array of dimensions by schema
 */
export function getDimensionsForSchema(selectedSchema, availableDimensions) {
  if (!selectedSchema) return [];

  return availableDimensions.filter(({ name }) => getMetricSchema(name) === selectedSchema);
}

/**
 * Selects a time dimension for a given schema
 */
export function getTimeDimensionForSchema(selectedSchema, availableTimeDimensions) {
  if (!selectedSchema) return null;

  const timeDimensions = availableTimeDimensions.filter(
    ({ name }) => getMetricSchema(name) === selectedSchema,
  );

  if (timeDimensions.length === 1) {
    // We only allow filtering by a single timeDimension. We expect most of our cubes to only have a single time dimension.
    return timeDimensions.at(0);
  }

  if (selectedSchema === SESSIONS_TABLE_NAME) {
    // Our `Sessions` cube is different, having both `startsAt`, `endsAt` timeDimensions.
    // We want to explicitly select the right dimension for Sessions so have this hardcoded lookup
    const sessionsDimensionName = DATE_RANGE_FILTER_DIMENSIONS[SESSIONS_TABLE_NAME.toLowerCase()];
    return timeDimensions.find(({ name }) => name === sessionsDimensionName);
  }

  // An unknown situation where a cube other than Sessions has more than one timeDimension. Hide it from the UI.
  return null;
}
