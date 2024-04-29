import {
  filterObjToFilterToken,
  filterTokensToFilterObj,
  filterObjToQuery,
  queryToFilterObj,
} from 'ee/logs/list/filter_bar/filters';

describe('utils', () => {
  const filterObj = {
    attributes: {
      service: [
        { operator: '=', value: 'serviceName' },
        { operator: '!=', value: 'serviceName2' },
      ],
      severityName: [
        { operator: '=', value: 'info' },
        { operator: '!=', value: 'warning' },
      ],
      traceId: [{ operator: '=', value: 'traceId' }],
      spanId: [{ operator: '=', value: 'spanId' }],
      fingerprint: [{ operator: '=', value: 'fingerprint' }],
      traceFlags: [
        { operator: '=', value: '1' },
        { operator: '!=', value: '2' },
      ],
      attribute: [{ operator: '=', value: 'attr=bar' }],
      resourceAttribute: [{ operator: '=', value: 'res=foo' }],
      search: [{ value: 'some-search' }],
    },
    dateRange: {
      value: 'custom',
      startDate: new Date('2020-01-01'),
      endDate: new Date('2020-01-02'),
    },
  };

  const queryObj = {
    attribute: ['attr=bar'],
    fingerprint: ['fingerprint'],
    'not[fingerprint]': null,
    'not[resourceAttribute]': null,
    'not[service]': ['serviceName2'],
    'not[severityName]': ['warning'],
    'not[spanId]': null,
    'not[traceFlags]': ['2'],
    'not[traceId]': null,
    'not[attribute]': null,
    resourceAttribute: ['res=foo'],
    search: 'some-search',
    service: ['serviceName'],
    severityName: ['info'],
    spanId: ['spanId'],
    traceFlags: ['1'],
    traceId: ['traceId'],
    date_range: 'custom',
    date_end: '2020-01-02T00:00:00.000Z',
    date_start: '2020-01-01T00:00:00.000Z',
  };

  const query =
    'attribute[]=attr%3Dbar' +
    '&fingerprint[]=fingerprint' +
    '&service[]=serviceName' +
    '&not%5Bservice%5D[]=serviceName2' +
    '&resourceAttribute[]=res%3Dfoo' +
    '&search[]=some-search' +
    '&severityName[]=info' +
    '&not%5BseverityName%5D[]=warning' +
    '&spanId[]=spanId' +
    '&traceFlags[]=1' +
    '&not%5BtraceFlags%5D[]=2' +
    '&traceId[]=traceId' +
    '&date_range=custom' +
    '&date_end=2020-01-02T00%3A00%3A00.000Z' +
    '&date_start=2020-01-01T00%3A00%3A00.000Z';

  const attributesFilterTokens = [
    {
      type: 'service-name',
      value: { data: 'serviceName', operator: '=' },
    },
    {
      type: 'service-name',
      value: { data: 'serviceName2', operator: '!=' },
    },
    { type: 'severity-name', value: { data: 'info', operator: '=' } },
    { type: 'severity-name', value: { data: 'warning', operator: '!=' } },
    { type: 'trace-id', value: { data: 'traceId', operator: '=' } },
    { type: 'span-id', value: { data: 'spanId', operator: '=' } },
    {
      type: 'fingerprint',
      value: { data: 'fingerprint', operator: '=' },
    },
    { type: 'trace-flags', value: { data: '1', operator: '=' } },
    { type: 'trace-flags', value: { data: '2', operator: '!=' } },
    { type: 'attribute', value: { data: 'attr=bar', operator: '=' } },
    {
      type: 'resource-attribute',
      value: { data: 'res=foo', operator: '=' },
    },
    {
      type: 'filtered-search-term',
      value: { data: 'some-search', operator: undefined },
    },
  ];

  describe('filterObjToFilterToken', () => {
    it('should convert filter object to filter tokens', () => {
      expect(filterObjToFilterToken(filterObj.attributes)).toEqual(attributesFilterTokens);
    });
  });

  describe('filterTokensToFilterObj', () => {
    it('should convert filter tokens to filter object', () => {
      expect(filterTokensToFilterObj(attributesFilterTokens)).toEqual(filterObj.attributes);
    });
  });

  describe('filterObjToQuery', () => {
    it('should convert filter object to query', () => {
      expect(filterObjToQuery(filterObj)).toEqual(queryObj);
    });

    it('handles missing attributes filter', () => {
      expect(
        filterObjToQuery({
          dateRange: {
            value: '7d',
          },
        }),
      ).toEqual({ date_range: '7d' });
    });

    it('handles empty values', () => {
      expect(filterObjToQuery({})).toEqual({});
    });
  });

  describe('queryToFilterObj', () => {
    it('should build a filter obj', () => {
      expect(queryToFilterObj(query)).toEqual(filterObj);
    });
  });
});
