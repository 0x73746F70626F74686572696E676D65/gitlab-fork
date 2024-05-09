import { s__, __ } from '~/locale';
import PanelsBase from './panels_base.vue';

export default {
  component: PanelsBase,
  title: 'ee/vue_shared/components/panels_base',
};

const Template = (args, { argTypes }) => ({
  components: { PanelsBase },
  props: Object.keys(argTypes),
  template: `
    <panels-base v-bind="$props" style="min-height: 7rem;">
      <template #body>
        <p><code>#body</code> slot content</p>
      </template>
      <template #error-popover>
        <div><code>#error-popover</code> slot content</div>
      </template>
    </panels-base>
  `,
});

export const Default = Template.bind({});
Default.args = {
  title: s__('ProductAnalytics|Audience'),
  tooltip: '',
  loading: false,
  showErrorState: false,
  errorPopoverTitle: '',
  actions: [],
  editing: false,
};

export const Loading = Template.bind({});
Loading.args = {
  ...Default.args,
  loading: true,
};

export const Error = Template.bind({});
Error.args = {
  ...Default.args,
  errorPopoverTitle: __('An error has occurred'),
  showErrorState: true,
};

export const Editing = Template.bind({});
Editing.args = {
  ...Default.args,
  editing: true,
  actions: [
    {
      text: __('Delete'),
      icon: 'remove',
      action: () => {},
    },
  ],
};
