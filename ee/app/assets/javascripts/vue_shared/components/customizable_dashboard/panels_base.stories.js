import { s__, __ } from '~/locale';
import { VARIANT_DANGER, VARIANT_WARNING, VARIANT_INFO } from '~/alert';
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
      <template #alert-popover>
        <div><code>#alert-popover</code> slot content</div>
      </template>
    </panels-base>
  `,
});

export const Default = Template.bind({});
Default.args = {
  title: s__('ProductAnalytics|Audience'),
  tooltip: '',
  loading: false,
  showAlertState: false,
  alertPopoverTitle: '',
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
  alertPopoverTitle: __('An error has occurred'),
  showAlertState: true,
  alertVariant: VARIANT_DANGER,
};

export const Warning = Template.bind({});
Warning.args = {
  ...Default.args,
  alertPopoverTitle: __('This is really just a warning'),
  showAlertState: true,
  alertVariant: VARIANT_WARNING,
};

export const Information = Template.bind({});
Information.args = {
  ...Default.args,
  alertPopoverTitle: __('Some friendly information'),
  showAlertState: true,
  alertVariant: VARIANT_INFO,
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
