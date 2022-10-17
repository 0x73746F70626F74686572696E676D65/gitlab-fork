import { GlLoadingIcon, GlTable, GlLink, GlBadge, GlPagination } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import getJobArtifactsResponse from 'test_fixtures/graphql/artifacts/graphql/queries/get_job_artifacts.query.graphql.json';
import CiIcon from '~/vue_shared/components/ci_icon.vue';
import waitForPromises from 'helpers/wait_for_promises';
import JobArtifactsTable from '~/artifacts/components/job_artifacts_table.vue';
import ArtifactRow from '~/artifacts/components/artifact_row.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import getJobArtifactsQuery from '~/artifacts/graphql/queries/get_job_artifacts.query.graphql';
import destroyArtifactMutation from '~/artifacts/graphql/mutations/destroy_artifact.mutation.graphql';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { ARCHIVE_FILE_TYPE, JOBS_PER_PAGE, i18n } from '~/artifacts/constants';
import { totalArtifactsSizeForJob } from '~/artifacts/utils';
import { createAlert } from '~/flash';

jest.mock('~/flash');

Vue.use(VueApollo);

describe('JobArtifactsTable component', () => {
  let wrapper;
  let requestHandlers;

  const findLoadingState = () => wrapper.findComponent(GlLoadingIcon);
  const findTable = () => wrapper.findComponent(GlTable);
  const findCount = () => wrapper.findByTestId('job-artifacts-count');

  const findStatuses = () => wrapper.findAllByTestId('job-artifacts-job-status');
  const findSuccessfulJobStatus = () => findStatuses().at(0);
  const findFailedJobStatus = () => findStatuses().at(1);

  const findLinks = () => wrapper.findAllComponents(GlLink);
  const findJobLink = () => findLinks().at(0);
  const findPipelineLink = () => findLinks().at(1);
  const findRefLink = () => findLinks().at(2);
  const findCommitLink = () => findLinks().at(3);

  const findSize = () => wrapper.findByTestId('job-artifacts-size');
  const findCreated = () => wrapper.findByTestId('job-artifacts-created');

  const findDownloadButton = () => wrapper.findByTestId('job-artifacts-download-button');
  const findBrowseButton = () => wrapper.findByTestId('job-artifacts-browse-button');
  const findDeleteButton = () => wrapper.findByTestId('job-artifacts-delete-button');

  const findPagination = () => wrapper.findComponent(GlPagination);
  const setPage = async (page) => {
    findPagination().vm.$emit('input', page);
    await waitForPromises();
  };

  let enoughJobsToPaginate = [...getJobArtifactsResponse.data.project.jobs.nodes];
  while (enoughJobsToPaginate.length <= JOBS_PER_PAGE) {
    enoughJobsToPaginate = [
      ...enoughJobsToPaginate,
      ...getJobArtifactsResponse.data.project.jobs.nodes,
    ];
  }
  const getJobArtifactsResponseThatPaginates = {
    data: { project: { jobs: { nodes: enoughJobsToPaginate } } },
  };

  const createComponent = (
    handlers = {
      getJobArtifactsQuery: jest.fn().mockResolvedValue(getJobArtifactsResponse),
      destroyArtifactMutation: jest.fn(),
    },
    data = {},
  ) => {
    requestHandlers = handlers;
    wrapper = mountExtended(JobArtifactsTable, {
      apolloProvider: createMockApollo([
        [getJobArtifactsQuery, requestHandlers.getJobArtifactsQuery],
        [destroyArtifactMutation, requestHandlers.destroyArtifactMutation],
      ]),
      provide: { projectPath: 'project/path' },
      data() {
        return data;
      },
    });
  };

  afterEach(() => {
    wrapper.destroy();
  });

  it('when loading, shows a loading state', () => {
    createComponent();

    expect(findLoadingState().exists()).toBe(true);
  });

  it('on error, shows an alert', async () => {
    createComponent({
      getJobArtifactsQuery: jest.fn().mockRejectedValue(new Error('Error!')),
    });

    await waitForPromises();

    expect(createAlert).toHaveBeenCalledWith({ message: i18n.fetchArtifactsError });
  });

  it('with data, renders the table', async () => {
    createComponent();

    await waitForPromises();

    expect(findTable().exists()).toBe(true);
  });

  describe('job details', () => {
    const job = getJobArtifactsResponse.data.project.jobs.nodes[0];
    const archiveArtifact = job.artifacts.nodes.find(
      (artifact) => artifact.fileType === ARCHIVE_FILE_TYPE,
    );

    beforeEach(async () => {
      createComponent();

      await waitForPromises();
    });

    it('shows the artifact count', () => {
      expect(findCount().text()).toBe(`${job.artifacts.nodes.length} files`);
    });

    it('expands to show the list of artifacts', async () => {
      jest.spyOn(wrapper.vm, 'handleRowToggle');

      findCount().trigger('click');

      expect(wrapper.vm.handleRowToggle).toHaveBeenCalled();
    });

    it('shows the job status as an icon for a successful job', () => {
      expect(findSuccessfulJobStatus().findComponent(CiIcon).exists()).toBe(true);
      expect(findSuccessfulJobStatus().findComponent(GlBadge).exists()).toBe(false);
    });

    it('shows the job status as a badge for other job statuses', () => {
      expect(findFailedJobStatus().findComponent(GlBadge).exists()).toBe(true);
      expect(findFailedJobStatus().findComponent(CiIcon).exists()).toBe(false);
    });

    it('shows links to the job, pipeline, ref, and commit', () => {
      expect(findJobLink().text()).toBe(job.name);
      expect(findJobLink().attributes('href')).toBe(job.webPath);

      expect(findPipelineLink().text()).toBe(`#${getIdFromGraphQLId(job.pipeline.id)}`);
      expect(findPipelineLink().attributes('href')).toBe(job.pipeline.path);

      expect(findRefLink().text()).toBe(job.refName);
      expect(findRefLink().attributes('href')).toBe(job.refPath);

      expect(findCommitLink().text()).toBe(job.shortSha);
      expect(findCommitLink().attributes('href')).toBe(job.commitPath);
    });

    it('shows the total size of artifacts', () => {
      expect(findSize().text()).toBe(totalArtifactsSizeForJob(job));
    });

    it('shows the created time', () => {
      expect(findCreated().text()).toBe('5 years ago');
    });

    it('shows the download, browse, and delete buttons', () => {
      expect(findDownloadButton().attributes('href')).toBe(archiveArtifact.downloadPath);
      expect(findBrowseButton().attributes('disabled')).toBe('disabled');
      expect(findDeleteButton().attributes('disabled')).toBe('disabled');
    });
  });

  describe('when an artifact row emits the delete event', () => {
    it('triggers the destroyArtifact GraphQL mutation', async () => {
      createComponent();
      await waitForPromises();

      findCount().trigger('click');
      await waitForPromises();

      wrapper.findComponent(ArtifactRow).vm.$emit('delete');

      expect(requestHandlers.destroyArtifactMutation).toHaveBeenCalled();
    });

    it('displays a flash message when the mutation fails', async () => {
      createComponent({
        getJobArtifactsQuery: jest.fn().mockResolvedValue(getJobArtifactsResponse),
        destroyArtifactMutation: jest.fn().mockRejectedValue(new Error('Error!')),
      });
      await waitForPromises();

      findCount().trigger('click');
      await waitForPromises();

      wrapper.findComponent(ArtifactRow).vm.$emit('delete');
      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith({ message: i18n.destroyArtifactError });
    });
  });

  describe('pagination', () => {
    const { pageInfo } = getJobArtifactsResponse.data.project.jobs;

    beforeEach(async () => {
      createComponent(
        {
          getJobArtifactsQuery: jest.fn().mockResolvedValue(getJobArtifactsResponseThatPaginates),
        },
        {
          jobArtifacts: {
            count: enoughJobsToPaginate.length,
            pageInfo,
          },
        },
      );

      await waitForPromises();
    });

    it('renders pagination and passes page props', () => {
      expect(findPagination().exists()).toBe(true);
      expect(findPagination().props()).toMatchObject({
        value: wrapper.vm.pagination.currentPage,
        prevPage: wrapper.vm.prevPage,
        nextPage: wrapper.vm.nextPage,
      });
    });

    it('updates query variables when going to previous page', () => {
      return setPage(1).then(() => {
        expect(wrapper.vm.queryVariables).toMatchObject({
          projectPath: 'project/path',
          nextPageCursor: undefined,
          prevPageCursor: pageInfo.startCursor,
        });
      });
    });

    it('updates query variables when going to next page', () => {
      return setPage(2).then(() => {
        expect(wrapper.vm.queryVariables).toMatchObject({
          lastPageSize: null,
          nextPageCursor: pageInfo.endCursor,
          prevPageCursor: '',
        });
      });
    });
  });
});
