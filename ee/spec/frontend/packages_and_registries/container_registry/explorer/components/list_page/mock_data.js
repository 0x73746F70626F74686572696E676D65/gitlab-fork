export const graphQLProjectContainerScanningForRegistryOnMock = {
  data: {
    project: {
      id: '1',
      containerScanningForRegistry: {
        isEnabled: true,
        isVisible: true,
        __typename: 'LocalContainerScanningForRegistry',
      },
      __typename: 'Project',
    },
  },
};

export const graphQLProjectContainerScanningForRegistryOffMock = {
  data: {
    project: {
      id: '1',
      containerScanningForRegistry: {
        isEnabled: false,
        isVisible: true,
        __typename: 'LocalContainerScanningForRegistry',
      },
      __typename: 'Project',
    },
  },
};

export const graphQLProjectContainerScanningForRegistryHiddenMock = {
  data: {
    project: {
      id: '1',
      containerScanningForRegistry: {
        isEnabled: false,
        isVisible: false,
        __typename: 'LocalContainerScanningForRegistry',
      },
      __typename: 'Project',
    },
  },
};
