import { filterObjToQuery, queryToFilterObj } from 'ee/metrics/details/filters';

describe('filterObjToQuery', () => {
  const query =
    'foo.bar[]=eq-val' +
    '&not%5Bfoo.bar%5D[]=not-eq-val' +
    '&like%5Bfoo.baz%5D[]=like-val' +
    '&not_like%5Bfoo.baz%5D[]=not-like-val' +
    '&group_by_fn=avg' +
    '&group_by_attrs[]=foo' +
    '&group_by_attrs[]=bar' +
    '&date_range=custom' +
    '&date_start=2020-01-01T00%3A00%3A00.000Z' +
    '&date_end=2020-01-02T00%3A00%3A00.000Z';

  const filterObj = {
    attributes: {
      'foo.bar': [
        { operator: '=', value: 'eq-val' },
        { operator: '!=', value: 'not-eq-val' },
      ],
      'foo.baz': [
        { operator: '=~', value: 'like-val' },
        { operator: '!~', value: 'not-like-val' },
      ],
    },
    groupBy: {
      func: 'avg',
      attributes: ['foo', 'bar'],
    },
    dateRange: {
      value: 'custom',
      startDate: new Date('2020-01-01'),
      endDate: new Date('2020-01-02'),
    },
  };

  const queryObj = {
    'foo.bar': ['eq-val'],
    'not[foo.bar]': ['not-eq-val'],
    'like[foo.bar]': null,
    'not_like[foo.bar]': null,
    'foo.baz': null,
    'not[foo.baz]': null,
    'like[foo.baz]': ['like-val'],
    'not_like[foo.baz]': ['not-like-val'],
    group_by_fn: 'avg',
    group_by_attrs: ['foo', 'bar'],
    date_range: 'custom',
    date_end: '2020-01-02T00:00:00.000Z',
    date_start: '2020-01-01T00:00:00.000Z',
  };

  describe('filterObjToQuery', () => {
    it('should convert filter object to URL query', () => {
      expect(filterObjToQuery(filterObj)).toEqual(queryObj);
    });

    it('handles empty group by attrs', () => {
      expect(
        filterObjToQuery({
          groupBy: {
            attributes: [],
          },
        }),
      ).toEqual({});
    });

    it('handles missing values', () => {
      expect(filterObjToQuery({})).toEqual({});
    });
  });

  describe('queryToFilterObj', () => {
    it('should build a filter obj', () => {
      expect(queryToFilterObj(query)).toEqual(filterObj);
    });

    it('handles empty group by attrs', () => {
      expect(queryToFilterObj('group_by_attrs[]=')).toEqual({
        attributes: {},
        dateRange: {
          value: '1h',
        },
        groupBy: {},
      });
    });

    it('ignores type in the query params', () => {
      expect(queryToFilterObj('type=foo&foo.bar[]=eq-val')).toEqual({
        attributes: {
          'foo.bar': [{ operator: '=', value: 'eq-val' }],
        },
        dateRange: {
          value: '1h',
        },
        groupBy: {},
      });
    });
  });
});
