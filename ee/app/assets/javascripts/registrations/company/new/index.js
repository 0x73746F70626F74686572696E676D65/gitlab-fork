import Vue from 'vue';
import apolloProvider from 'ee/subscriptions/buy_addons_shared/graphql';
import CompanyForm from 'ee/registrations/components/company_form.vue';
import { parseBoolean } from '~/lib/utils/common_utils';

export default () => {
  const el = document.querySelector('#js-registrations-company-form');
  const { submitPath, firstName, lastName, initialTrial } = el.dataset;

  return new Vue({
    el,
    apolloProvider,
    provide: {
      user: {
        firstName,
        lastName,
      },
      submitPath,
      initialTrial: parseBoolean(initialTrial),
    },
    render(createElement) {
      return createElement(CompanyForm);
    },
  });
};
