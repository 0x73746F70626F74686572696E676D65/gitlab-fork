import { STEPS } from 'ee/subscriptions/constants';
import {
  CUSTOMER_TYPE,
  NAMESPACE_TYPE,
  PAYMENT_METHOD_TYPE,
  PLAN_TYPE,
  SUBSCRIPTION_TYPE,
  ORDER_PREVIEW_TYPE,
} from 'ee/subscriptions/buy_addons_shared/constants';

export const accountId = '111111111111';
export const subscriptionName = 'A-000000000';

export const mockCiMinutesPlans = [
  {
    id: 'ciMinutesPackPlanId',
    code: 'ci_minutes',
    isAddon: true,
    pricePerYear: 10,
    name: 'Compute minutes pack',
    __typename: PLAN_TYPE,
  },
];

export const mockStoragePlans = [
  {
    id: 'storagePackPlanId',
    code: 'storage',
    pricePerYear: 60,
    name: 'Storage pack',
    __typename: PLAN_TYPE,
  },
];

export const mockNamespaces = `
  [{"id":132,"accountId":"${accountId}","name":"Gitlab Org"},
  {"id":483,"accountId":null,"name":"Gnuwget"}]
`;

export const mockParsedNamespaces = JSON.parse(mockNamespaces).map((namespace) => ({
  ...namespace,
  __typename: NAMESPACE_TYPE,
}));

export const mockNewUser = 'false';
export const mockSetupForCompany = 'true';

export const mockDefaultCache = {
  groupData: mockNamespaces,
  namespaceId: 132,
  redirectAfterSuccess: '/',
};

export const mockOrderPreview = {
  targetDate: '2022-12-15',
  amount: 59.67,
  amountWithoutTax: 60.0,
  __typename: ORDER_PREVIEW_TYPE,
};

export const stateData = {
  eligibleNamespaces: [],
  subscription: {
    quantity: 1,
    __typename: SUBSCRIPTION_TYPE,
  },
  activeSubscription: {
    name: subscriptionName,
    __typename: SUBSCRIPTION_TYPE,
  },
  redirectAfterSuccess: '/path/to/redirect/',
  selectedNamespaceId: '30',
  selectedPlan: {
    id: 1,
    isAddon: true,
  },
  paymentMethod: {
    id: 1,
    creditCardExpirationMonth: null,
    creditCardExpirationYear: null,
    creditCardType: null,
    creditCardMaskNumber: null,
    __typename: PAYMENT_METHOD_TYPE,
  },
  customer: {
    country: null,
    address1: null,
    address2: null,
    city: null,
    state: null,
    zipCode: 94100,
    company: null,
    __typename: CUSTOMER_TYPE,
  },
  fullName: 'Full Name',
  isNewUser: false,
  isSetupForCompany: true,
  stepList: STEPS,
  activeStep: STEPS[0],
  furthestAccessedStep: STEPS[1],
};

export const mockChargeItem = {
  chargeAmount: 48,
  processingType: 'Charge',
  unitPrice: 48,
};

export const mockInvoicePreviewBronze = {
  data: {
    invoicePreview: {
      invoice: {
        amountWithoutTax: 48,
      },
      invoiceItem: [mockChargeItem],
      metaData: {
        showPromotionalOfferText: false,
      },
    },
  },
};

export const mockDiscountItem = {
  chargeAmount: -10,
  processingType: 'Discount',
  unitPrice: 10,
};

export const mockInvoicePreviewUltimate = {
  data: {
    invoicePreview: {
      invoice: {
        amountWithoutTax: 1188,
      },
      invoiceItem: [
        {
          chargeAmount: 1188,
          processingType: 'Charge',
          unitPrice: 1188,
        },
      ],
      metaData: {
        showPromotionalOfferText: false,
      },
    },
  },
};

export const mockInvoicePreviewWithDiscount = {
  data: {
    invoicePreview: {
      invoice: {
        amountWithoutTax: 1188,
      },
      invoiceItem: [
        {
          chargeAmount: 1188,
          processingType: 'Charge',
          unitPrice: 1188,
        },
        mockDiscountItem,
      ],
      metaData: {
        showPromotionalOfferText: false,
      },
    },
  },
};

export const mockInvoicePreviewUltimateWithMultipleUsers = {
  data: {
    invoicePreview: {
      invoice: {
        amountWithoutTax: 3564,
      },
      invoiceItem: [
        {
          chargeAmount: 3564,
          processingType: 'Charge',
          unitPrice: 1188,
        },
      ],
      metaData: {
        showPromotionalOfferText: false,
      },
    },
  },
};

export const mockInvoicePreviewWithPromoOffer = {
  data: {
    invoicePreview: {
      invoice: {
        amountWithoutTax: 48,
      },
      invoiceItem: [mockChargeItem],
      metaData: {
        showPromotionalOfferText: true,
      },
    },
  },
};

export const mockInvoicePreviewWithoutPromoOffer = {
  data: {
    invoicePreview: {
      invoice: {
        amountWithoutTax: 48,
      },
      invoiceItem: [mockChargeItem],
      metaData: {
        showPromotionalOfferText: false,
      },
    },
  },
};

export const mockBillingAccount = {
  zuoraAccountName: 'Day Off LLC',
  zuoraAccountVatId: 1234,
  vatFieldVisible: 'true',
  billingAccountCustomers: {
    id: 1234,
    email: 'day@off.com',
    firstName: 'Ferris',
    lastName: 'Bueller',
    fullName: 'Ferris Bueller',
    alternativeContactFullNames: [],
    alternativeContactFirstNames: [],
    alternativeContactLastNames: [],
  },
  soldToContact: {
    id: 5678,
    firstName: 'Jeanie',
    lastName: 'Bueller',
    fullName: 'Jeanie Bueller',
    workEmail: 'jeanie@dayoff.com',
    address1: '123 Green St',
    address2: 'Apt 2',
    city: 'Chicago',
    state: 'IL',
    postalCode: 99999,
    country: 'USA',
  },
  billToContact: {
    id: 5678,
    firstName: 'Jeanie',
    lastName: 'Bueller',
    fullName: 'Jeanie Bueller',
    workEmail: 'jeanie@dayoff.com',
    address1: '123 Green St',
    address2: 'Apt 2',
    city: 'Chicago',
    state: 'IL',
    postalCode: 99999,
    country: 'USA',
  },
};
