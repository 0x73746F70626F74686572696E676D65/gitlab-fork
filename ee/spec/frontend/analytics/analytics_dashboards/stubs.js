export const BuilderComponent = {
  data() {
    return {
      resultSet: {
        query: () => ({ foo: 'bar' }),
      },
    };
  },
  template: '<div><slot></slot></div>',
};

export const getQueryBuilderStub = (mockData) => ({
  data() {
    return {
      loading: false,
      filters: [],
      measures: [],
      dimensions: [],
      timeDimensions: [],
      availableMeasures: [],
      availableDimensions: [],
      availableTimeDimensions: [],
      setMeasures: () => {},
      setFilters: () => {},
      addFilters: () => {},
      addDimensions: () => {},
      removeDimensions: () => {},
      setTimeDimensions: () => {},
      removeTimeDimensions: () => {},
      setSegments: () => {},
      ...mockData,
    };
  },
  template: `
    <builder-component>
      <slot name="builder" v-bind="{measures, dimensions, timeDimensions, availableMeasures, availableDimensions, availableTimeDimensions, setTimeDimensions, removeTimeDimensions, removeDimensions, addDimensions, filters, setMeasures, setFilters, addFilters, setSegments }"></slot>
      <slot v-bind="{loading}"></slot>
    </builder-component>
  `,
});
