import {
  queryToFilterObj,
  filterObjToQuery,
  filterObjToFilterToken,
  filterTokensToFilterObj,
} from 'ee/tracing/list/filter_bar/filters';

describe('utils', () => {
  const query =
    'sortBy=timestamp_desc' +
    '&period[]=1h' +
    '&service[]=accountingservice&not%5Bservice%5D[]=adservice' +
    '&operation[]=orders%20receive&not%5Boperation%5D[]=orders%20receive' +
    '&gt%5BdurationMs%5D[]=100&lt%5BdurationMs%5D[]=1000' +
    '&trace_id[]=9609bf00-4b68-f86c-abe2-5e23d0089c83' +
    '&not%5Btrace_id%5D[]=9609bf00-4b68-f86c-abe2-5e23d0089c83' +
    '&attribute[]=foo%3Dbar&attribute[]=baz%3Dbar' +
    '&status[]=ok&not%5Bstatus%5D[]=error' +
    '&search=searchquery';

  const filterObj = {
    attributes: {
      period: [{ operator: '=', value: '1h' }],
      service: [
        { operator: '=', value: 'accountingservice' },
        { operator: '!=', value: 'adservice' },
      ],
      operation: [
        { operator: '=', value: 'orders receive' },
        { operator: '!=', value: 'orders receive' },
      ],
      traceId: [
        { operator: '=', value: '9609bf00-4b68-f86c-abe2-5e23d0089c83' },
        { operator: '!=', value: '9609bf00-4b68-f86c-abe2-5e23d0089c83' },
      ],
      durationMs: [
        { operator: '>', value: '100' },
        { operator: '<', value: '1000' },
      ],
      attribute: [
        { operator: '=', value: 'foo=bar' },
        { operator: '=', value: 'baz=bar' },
      ],
      status: [
        { operator: '=', value: 'ok' },
        { operator: '!=', value: 'error' },
      ],
      search: [{ value: 'searchquery' }],
    },
  };

  const queryObj = {
    attribute: ['foo=bar', 'baz=bar'],
    durationMs: null,
    'gt[durationMs]': ['100'],
    'lt[durationMs]': ['1000'],
    'not[attribute]': null,
    'not[durationMs]': null,
    'not[operation]': ['orders receive'],
    'not[period]': null,
    'not[service]': ['adservice'],
    'not[trace_id]': ['9609bf00-4b68-f86c-abe2-5e23d0089c83'],
    'not[status]': ['error'],
    operation: ['orders receive'],
    period: ['1h'],
    status: ['ok'],
    search: 'searchquery',
    service: ['accountingservice'],
    trace_id: ['9609bf00-4b68-f86c-abe2-5e23d0089c83'],
  };

  const attributesFilterTokens = [
    { type: 'period', value: { data: '1h', operator: '=' } },
    { type: 'service-name', value: { data: 'accountingservice', operator: '=' } },
    { type: 'service-name', value: { data: 'adservice', operator: '!=' } },
    { type: 'operation', value: { data: 'orders receive', operator: '=' } },
    { type: 'operation', value: { data: 'orders receive', operator: '!=' } },
    {
      type: 'trace-id',
      value: { data: '9609bf00-4b68-f86c-abe2-5e23d0089c83', operator: '=' },
    },
    {
      type: 'trace-id',
      value: { data: '9609bf00-4b68-f86c-abe2-5e23d0089c83', operator: '!=' },
    },
    { type: 'duration-ms', value: { data: '100', operator: '>' } },
    { type: 'duration-ms', value: { data: '1000', operator: '<' } },
    { type: 'attribute', value: { data: 'foo=bar', operator: '=' } },
    { type: 'attribute', value: { data: 'baz=bar', operator: '=' } },
    { type: 'filtered-search-term', value: { data: 'searchquery', operator: undefined } },
    { type: 'status', value: { data: 'ok', operator: '=' } },
    { type: 'status', value: { data: 'error', operator: '!=' } },
  ];

  describe('queryToFilterObj', () => {
    it('should build a filter obj', () => {
      expect(queryToFilterObj(query)).toEqual(filterObj);
    });

    it('should add the default period filter if not specified', () => {
      expect(queryToFilterObj('service[]=accountingservice')).toEqual({
        attributes: {
          period: [{ operator: '=', value: '1h' }],
          service: [{ operator: '=', value: 'accountingservice' }],
        },
      });
    });

    it.each(['5m', '15m', '30m', '1h', '4h', '12h', '24h', '7d', '2024-02-15 - 2024-02-22'])(
      'handles valid periods',
      (value) => {
        expect(queryToFilterObj(`period[]=${value}`)).toEqual({
          attributes: {
            period: [{ operator: '=', value }],
          },
        });
      },
    );

    it.each(['30d', 'foo', 'foo - bar', '123-456', '2024-02-01 - 2024-02-20'])(
      'ignores invalid period',
      (val) => {
        expect(queryToFilterObj(`period[]=${val}`)).toEqual({
          attributes: {
            period: [{ operator: '=', value: '1h' }],
          },
        });
      },
    );
  });

  describe('filterObjToQuery', () => {
    it('should convert filter object to URL query', () => {
      expect(filterObjToQuery(filterObj)).toEqual(queryObj);
    });
  });

  describe('filterObjToFilterToken', () => {
    it('should convert filter object to filter tokens', () => {
      expect(filterObjToFilterToken(filterObj.attributes)).toEqual(attributesFilterTokens);
    });
  });

  describe('filterTokensToFilterObj', () => {
    it('should convert filter tokens to filter object', () => {
      expect(filterTokensToFilterObj(attributesFilterTokens)).toEqual(filterObj.attributes);
    });

    it('should add the default period filter it not specified', () => {
      expect(
        filterTokensToFilterObj([{ type: 'duration-ms', value: { data: '100', operator: '>' } }]),
      ).toEqual({
        period: [{ operator: '=', value: '1h' }],
        durationMs: [{ operator: '>', value: '100' }],
      });
    });
  });
});
