import { GlButton, GlFormGroup } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import Step from 'ee/vue_shared/purchase_flow/components/step.vue';
import StepHeader from 'ee/vue_shared/purchase_flow/components/step_header.vue';
import { GENERAL_ERROR_MESSAGE } from 'ee/vue_shared/purchase_flow/constants';
import updateStepMutation from 'ee/vue_shared/purchase_flow/graphql/mutations/update_active_step.mutation.graphql';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';
import { createMockApolloProvider } from '../spec_helper';
import { STEPS } from '../mock_data';

Vue.use(VueApollo);

jest.mock('~/alert');

describe('Step', () => {
  let wrapper;
  const initialProps = {
    stepId: STEPS[1].id,
    isValid: true,
    title: 'title',
    nextStepButtonText: 'next',
  };
  const summaryClass = 'step-summary';

  function activateFirstStep(apolloProvider) {
    return apolloProvider.clients.defaultClient.mutate({
      mutation: updateStepMutation,
      variables: { id: STEPS[0].id },
    });
  }

  function createComponent(options = {}) {
    const { apolloProvider, propsData } = options;

    wrapper = shallowMountExtended(Step, {
      propsData: { ...initialProps, ...propsData },
      apolloProvider,
      slots: {
        summary: `<p class="${summaryClass}">Some summary</p>`,
      },
      stubs: {
        StepHeader,
      },
    });
  }

  afterEach(() => {
    createAlert.mockClear();
  });

  const findStepHeader = () => wrapper.findComponent(StepHeader);
  const findEditButton = () => findStepHeader().findComponent(GlButton);
  const findActiveStepBody = () => wrapper.findByTestId('active-step-body');
  const findNextButton = () => findActiveStepBody().findComponent(GlButton);
  const findFormGroup = () => findActiveStepBody().findComponent(GlFormGroup);
  const findStepSummary = () => wrapper.find(`.${summaryClass}`);

  describe('Step Body', () => {
    describe('when initialStepIndex step is the current step', () => {
      beforeEach(() => {
        const mockApollo = createMockApolloProvider(STEPS, 1);
        createComponent({ apolloProvider: mockApollo });
      });

      it('displays the step body', () => {
        expect(findActiveStepBody().isVisible()).toBe(true);
      });

      it('does not display the form group', () => {
        expect(findFormGroup().exists()).toBe(false);
      });
    });

    describe('when initialStepIndex step is not the current step', () => {
      beforeEach(async () => {
        const mockApollo = createMockApolloProvider(STEPS, 1);
        await activateFirstStep(mockApollo);
        createComponent({ apolloProvider: mockApollo });
      });

      it('does not display the step body', () => {
        expect(findActiveStepBody().isVisible()).toBe(false);
      });

      it('does not display the form group', () => {
        expect(findFormGroup().exists()).toBe(false);
      });
    });
  });

  describe('when step is invalid', () => {
    let mockApollo;
    beforeEach(() => {
      mockApollo = createMockApolloProvider(STEPS, 1);
    });

    describe('with error message', () => {
      const errorMessage = 'Oh no!';
      beforeEach(() => {
        createComponent({
          propsData: { isValid: false, errorMessage },
          apolloProvider: mockApollo,
        });
      });

      it('displays form group', () => {
        expect(findFormGroup().exists()).toBe(true);
      });

      it('sets invalid feedback on form group', () => {
        expect(findFormGroup().attributes('invalid-feedback')).toBe(errorMessage);
      });
    });

    describe('without error message', () => {
      beforeEach(() => {
        createComponent({
          propsData: { isValid: false },
          apolloProvider: mockApollo,
        });
      });

      it('does not display form group', () => {
        expect(findFormGroup().exists()).toBe(false);
      });
    });
  });

  describe('Step Summary', () => {
    it('should be shown when this step is valid and not active', async () => {
      const mockApollo = createMockApolloProvider(STEPS, 1);
      await activateFirstStep(mockApollo);
      createComponent({ apolloProvider: mockApollo });

      expect(findStepSummary().exists()).toBe(true);
    });

    it('displays an error when editing a wrong step', async () => {
      const mockApollo = createMockApolloProvider(STEPS, 1);

      await activateFirstStep(mockApollo);
      createComponent({
        propsData: { stepId: 'does not exist' },
        apolloProvider: mockApollo,
      });

      findEditButton().vm.$emit('click');
      await waitForPromises();

      expect(createAlert.mock.calls).toHaveLength(1);
      expect(createAlert.mock.calls[0][0]).toMatchObject({
        message: GENERAL_ERROR_MESSAGE,
        captureError: true,
        error: expect.any(Error),
      });
    });

    it('passes the correct text to the edit button', () => {
      createComponent({
        propsData: { editButtonText: 'Change' },
      });

      expect(findStepHeader().props('editButtonText')).toBe('Change');
    });

    it('should not be shown when this step is not valid and not active', async () => {
      const mockApollo = createMockApolloProvider(STEPS, 1);
      await activateFirstStep(mockApollo);
      createComponent({ propsData: { isValid: false }, apolloProvider: mockApollo });

      expect(findStepSummary().exists()).toBe(false);
    });

    it('should not be shown when this step is valid and active', () => {
      const mockApollo = createMockApolloProvider(STEPS, 1);
      createComponent({ apolloProvider: mockApollo });

      expect(findStepSummary().exists()).toBe(false);
    });

    it('should not be shown when this step is not valid and active', () => {
      const mockApollo = createMockApolloProvider(STEPS, 1);
      createComponent({ propsData: { isValid: false }, apolloProvider: mockApollo });

      expect(findStepSummary().exists()).toBe(false);
    });
  });

  it('should pass correct props to form component', () => {
    createComponent({
      propsData: { isValid: false, errorMessage: 'Input value is invalid!' },
    });

    expect(wrapper.findComponent(GlFormGroup).attributes('invalid-feedback')).toBe(
      'Input value is invalid!',
    );
  });

  describe('Step header', () => {
    describe('when step is finished and comes before current step', () => {
      beforeEach(() => {
        const mockApollo = createMockApolloProvider(STEPS, 1);
        createComponent({
          propsData: { stepId: STEPS[0].id },
          apolloProvider: mockApollo,
        });
      });

      it('has isEditable prop set to true', () => {
        expect(findStepHeader().props('isEditable')).toBe(true);
      });

      it('has isFinished prop set to true', () => {
        expect(findStepHeader().props('isFinished')).toBe(true);
      });
    });

    describe('when step is valid but comes after furthestAccessedStep', () => {
      beforeEach(() => {
        const mockApollo = createMockApolloProvider(STEPS, 0);
        createComponent({
          propsData: { stepId: STEPS[2].id, isValid: true },
          apolloProvider: mockApollo,
        });
      });

      it('has isEditable prop set to false', () => {
        expect(findStepHeader().props('isEditable')).toBe(false);
      });

      it('has isFinished prop set to false', () => {
        expect(findStepHeader().props('isFinished')).toBe(false);
      });
    });
  });

  describe('Showing the summary', () => {
    it('shows the summary when this step is finished', async () => {
      const mockApollo = createMockApolloProvider(STEPS, 1);
      await activateFirstStep(mockApollo);
      createComponent({ apolloProvider: mockApollo });

      expect(findStepSummary().exists()).toBe(true);
    });

    it('does not show the summary when this step is not finished', () => {
      const mockApollo = createMockApolloProvider(STEPS, 1);
      createComponent({ apolloProvider: mockApollo });

      expect(findStepSummary().exists()).toBe(false);
    });
  });

  describe('Next button', () => {
    it('shows the next button when the text was passed', () => {
      const mockApollo = createMockApolloProvider(STEPS, 1);
      createComponent({ apolloProvider: mockApollo });

      expect(findNextButton().text()).toBe('next');
    });

    it('does not show the next button when no text was passed', () => {
      const mockApollo = createMockApolloProvider(STEPS, 1);
      createComponent({
        propsData: { nextStepButtonText: '' },
        apolloProvider: mockApollo,
      });

      expect(findNextButton().exists()).toBe(false);
    });

    it('is disabled when this step is not valid', () => {
      const mockApollo = createMockApolloProvider(STEPS, 1);
      createComponent({ propsData: { isValid: false }, apolloProvider: mockApollo });

      expect(wrapper.findComponent(GlButton).attributes('disabled')).toBeDefined();
    });

    it('is enabled when this step is valid', () => {
      const mockApollo = createMockApolloProvider(STEPS, 1);
      createComponent({ apolloProvider: mockApollo });

      expect(findNextButton().attributes('disabled')).toBeUndefined();
    });

    it('displays an error if navigating too far', async () => {
      const mockApollo = createMockApolloProvider(STEPS, 2);
      createComponent({ propsData: { stepId: STEPS[2].id }, apolloProvider: mockApollo });

      findNextButton().vm.$emit('click');
      await waitForPromises();

      expect(createAlert.mock.calls).toHaveLength(1);
      expect(createAlert.mock.calls[0][0]).toMatchObject({
        message: GENERAL_ERROR_MESSAGE,
        captureError: true,
        error: expect.any(Error),
      });
    });
  });

  describe('when step is edited', () => {
    let mockApollo;
    let mockUpdateStepResolver;
    beforeEach(() => {
      mockUpdateStepResolver = jest.fn();

      // start with the third step (STEPS[2]) as the activeStep
      mockApollo = createMockApolloProvider(STEPS, 2, {
        Mutation: {
          updateActiveStep: mockUpdateStepResolver,
        },
      });

      createComponent({ propsData: { stepId: STEPS[1].id }, apolloProvider: mockApollo });
    });

    it('emits stepEdit event', async () => {
      // click the "Edit" button for the second step
      findEditButton().vm.$emit('click');
      await waitForPromises();

      expect(wrapper.emitted().stepEdit[0]).toEqual(['secondStep']);
    });

    it('calls updateStep mutation', async () => {
      findEditButton().vm.$emit('click');
      await waitForPromises();

      expect(mockUpdateStepResolver).toHaveBeenCalledTimes(1);
      expect(mockUpdateStepResolver).toHaveBeenCalledWith(
        {},
        { id: STEPS[1].id },
        expect.anything(),
        expect.anything(),
      );
    });
  });

  describe('when next step is triggered', () => {
    let mockApollo;
    let activateNextStepResolver;

    beforeEach(async () => {
      activateNextStepResolver = jest.fn();
      mockApollo = createMockApolloProvider(STEPS, 1, {
        Mutation: {
          activateNextStep: activateNextStepResolver,
        },
      });

      createComponent({ propsData: { stepId: STEPS[0].id }, apolloProvider: mockApollo });
      await activateFirstStep(mockApollo);
      await waitForPromises();
    });

    it('emits nextStep on step transition', async () => {
      wrapper.findComponent(GlButton).vm.$emit('click');

      await waitForPromises();

      expect(wrapper.emitted().nextStep).toHaveLength(1);
    });

    it('triggers activateNextStep mutation', async () => {
      wrapper.findComponent(GlButton).vm.$emit('click');

      await waitForPromises();

      expect(activateNextStepResolver).toHaveBeenCalledTimes(1);
    });
  });
});
