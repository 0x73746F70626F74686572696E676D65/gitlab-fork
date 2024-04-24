import Vue from 'vue';
import HandRaiseLead from 'ee/hand_raise_leads/hand_raise_lead/components/hand_raise_lead.vue';
import apolloProvider from 'ee/subscriptions/buy_addons_shared/graphql';
import { PQL_BUTTON_TEXT } from './constants';

export const initHandRaiseLead = (el) => {
  const {
    namespaceId,
    userName,
    firstName,
    lastName,
    companyName,
    glmContent,
    productInteraction,
    trackCategory,
    trackAction,
    trackLabel,
    trackProperty,
    trackValue,
    trackExperiment,
    buttonAttributes,
    buttonText,
    createHandRaiseLeadPath,
  } = el.dataset;

  return new Vue({
    el,
    apolloProvider,
    provide: {
      createHandRaiseLeadPath,
      buttonAttributes: buttonAttributes && JSON.parse(buttonAttributes),
      buttonText: buttonText || PQL_BUTTON_TEXT,
      user: {
        namespaceId,
        userName,
        firstName,
        lastName,
        companyName,
        glmContent,
        productInteraction,
      },
      ctaTracking: {
        category: trackCategory,
        action: trackAction,
        label: trackLabel,
        property: trackProperty,
        value: trackValue,
        experiment: trackExperiment,
      },
    },
    render(createElement) {
      return createElement(HandRaiseLead);
    },
  });
};
