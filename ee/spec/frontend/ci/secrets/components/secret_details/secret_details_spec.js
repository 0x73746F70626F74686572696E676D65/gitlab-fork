import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import SecretDetails from 'ee/ci/secrets/components/secret_details/secret_details.vue';
import { localeDateFormat } from '~/lib/utils/datetime_utility';
import { mockSecret } from '../../mock_data';

describe('SecretDetails component', () => {
  let wrapper;

  const findKey = () => wrapper.findByTestId('secret-details-key');
  const findCreatedAt = () => wrapper.findByTestId('secret-details-created-at');
  const findDescription = () => wrapper.findByTestId('secret-details-description');
  const findExpiration = () => wrapper.findByTestId('secret-details-expiration');
  const findRotationPeriod = () => wrapper.findByTestId('secret-details-rotation-period');

  const createComponent = ({ customSecret } = {}) => {
    wrapper = shallowMountExtended(SecretDetails, {
      propsData: {
        secret: {
          ...mockSecret(),
          ...customSecret,
        },
      },
    });
  };

  describe('template', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders and formats secret information', () => {
      const localizedCreatedAt = localeDateFormat.asDateTimeFull.format(mockSecret().createdAt);
      const localizedExpiration = localeDateFormat.asDateTimeFull.format(mockSecret().expiration);

      expect(findKey().text()).toBe('APP_PWD');
      expect(findCreatedAt().text()).toBe(localizedCreatedAt);
      expect(findDescription().text()).toBe('This is a secret');
      expect(findExpiration().text()).toBe(localizedExpiration);
      expect(findRotationPeriod().text()).toBe('Every 2 weeks');
    });
  });

  describe('with required fields only', () => {
    beforeEach(() => {
      createComponent({
        customSecret: {
          description: undefined,
          rotationPeriod: undefined,
        },
      });
    });

    it("renders 'None' for optional fields that don't have values", () => {
      expect(findDescription().text()).toBe('None');
      expect(findRotationPeriod().text()).toBe('None');
    });
  });
});
