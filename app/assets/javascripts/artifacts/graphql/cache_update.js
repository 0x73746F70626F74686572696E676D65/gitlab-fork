import produce from 'immer';

export const hasErrors = ({ errors = [] }) => errors?.length;

export function removeArtifactFromStore(store, deletedArtifactId, query, variables) {
  if (!hasErrors(deletedArtifactId)) {
    const sourceData = store.readQuery({
      query,
      variables,
    });

    const data = produce(sourceData, (draftData) => {
      draftData.project.jobs.nodes = draftData.project.jobs.nodes.map((jobNode) => {
        return {
          ...jobNode,
          artifacts: {
            ...jobNode.artifacts,
            nodes: jobNode.artifacts.nodes.filter(({ id }) => id !== deletedArtifactId),
          },
        };
      });
    });

    store.writeQuery({
      query,
      variables,
      data,
    });
  }
}
