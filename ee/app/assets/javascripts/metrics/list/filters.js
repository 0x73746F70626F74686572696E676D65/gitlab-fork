import {
  filterToQueryObject,
  urlQueryToFilter,
  prepareTokens,
  processFilters,
} from '~/vue_shared/components/filtered_search_bar/filtered_search_utils';
import { FILTERED_SEARCH_TERM } from '~/vue_shared/components/filtered_search_bar/constants';
import { FILTERED_SEARCH_TERM_QUERY_KEY } from '~/observability/constants';

export const ATTRIBUTE_FILTER_TOKEN_TYPE = 'attribute';

export function queryToFilterObj(query) {
  const filter = urlQueryToFilter(query, {
    filteredSearchTermKey: FILTERED_SEARCH_TERM_QUERY_KEY,
  });
  const { attribute = undefined } = filter;
  const search = filter[FILTERED_SEARCH_TERM];
  return {
    attribute,
    search,
  };
}

export function filterObjToQuery(filters) {
  return filterToQueryObject(
    {
      [FILTERED_SEARCH_TERM]: filters.search,
      [ATTRIBUTE_FILTER_TOKEN_TYPE]: filters.attribute,
    },
    {
      filteredSearchTermKey: FILTERED_SEARCH_TERM_QUERY_KEY,
    },
  );
}

export function filterObjToFilterToken(filters) {
  return prepareTokens({
    [FILTERED_SEARCH_TERM]: filters.search,
    [ATTRIBUTE_FILTER_TOKEN_TYPE]: filters.attribute,
  });
}

export function filterTokensToFilterObj(tokens) {
  const { [FILTERED_SEARCH_TERM]: search, [ATTRIBUTE_FILTER_TOKEN_TYPE]: attribute } =
    processFilters(tokens);

  return {
    search,
    attribute,
  };
}
