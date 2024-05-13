# frozen_string_literal: true

module EE
  module Projects
    module UpdatePagesService
      extend ::Gitlab::Utils::Override

      override :pages_deployment_attributes
      def pages_deployment_attributes(file, build)
        super.merge(path_prefix: path_prefix)
      end

      private

      def path_prefix
        ::Gitlab::Utils.slugify(build.pages&.fetch(:path_prefix, ''))
      end
    end
  end
end
