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
      availableMeasures: [],
      availableDimensions: [],
      availableTimeDimensions: [],
      ...mockData,
    };
  },
  template: `
    <builder-component>
      <slot name="builder" v-bind="{ availableMeasures, availableDimensions, availableTimeDimensions }"></slot>
      <slot v-bind="{loading}"></slot>
    </builder-component>
  `,
});
