# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe Sidebars::Concerns::SuperSidebarPanel, feature_category: :navigation do
  let(:menu_class_foo) { Class.new(Sidebars::Menu) }
  let(:menu_foo) { menu_class_foo.new({}) }

  let(:menu_class_bar) do
    Class.new(Sidebars::Menu) do
      def title
        "Bar"
      end
    end
  end

  let(:menu_bar) { menu_class_bar.new({}) }

  subject do
    Class.new(Sidebars::Panel) do
      include Sidebars::Concerns::SuperSidebarPanel
    end.new({})
  end

  before do
    allow(menu_foo).to receive(:render?).and_return(true)
    allow(menu_bar).to receive(:render?).and_return(true)
  end

  describe '#pick_from_old_menus' do
    it 'removes element of a given class from a list and adds it to menus' do
      old_menus = [menu_foo, menu_bar]

      subject.pick_from_old_menus(old_menus, menu_class_foo)

      expect(old_menus).not_to include(menu_foo)
      expect(subject.renderable_menus).to include(menu_foo)
    end

    it 'is a noop, if the list does not contain an element of the wanted class' do
      old_menus = [menu_foo]

      subject.pick_from_old_menus(old_menus, menu_class_bar)

      expect(old_menus).to eq([menu_foo])
      expect(subject.renderable_menus).to eq([])
    end
  end

  describe '#transform_old_menus' do
    let(:menu_item) do
      Sidebars::MenuItem.new(title: 'foo3', link: 'foo3', active_routes: { controller: 'barc' },
        super_sidebar_parent: menu_class_foo)
    end

    let(:nil_menu_item) { Sidebars::NilMenuItem.new(item_id: :nil_item) }
    let(:existing_item) do
      Sidebars::MenuItem.new(
        item_id: :exists,
        title: 'Existing item',
        link: 'foo2',
        active_routes: { controller: 'foo2' }
      )
    end

    let(:current_menus) { [menu_foo] }

    before do
      menu_foo.add_item(existing_item)
    end

    context 'for Menus with Menu Items' do
      before do
        menu_bar.add_item(menu_item)
        menu_bar.add_item(nil_menu_item)
      end

      it 'adds Menu Items to defined super_sidebar_parent' do
        subject.transform_old_menus(current_menus, menu_bar)

        expect(menu_foo.renderable_items).to eq([existing_item, menu_item])
      end

      it 'adds Menu Items to defined super_sidebar_parent, before super_sidebar_before' do
        allow(menu_item).to receive(:super_sidebar_before).and_return(:exists)
        subject.transform_old_menus(current_menus, menu_bar)

        expect(menu_foo.renderable_items).to eq([menu_item, existing_item])
      end

      it 'drops Menu Items if super_sidebar_parent is nil' do
        allow(menu_item).to receive(:super_sidebar_parent).and_return(nil)
        subject.transform_old_menus(current_menus, menu_bar)

        expect(menu_foo.renderable_items).to eq([existing_item])
      end
    end

    it 'converts "solo" top-level Menu entry to Menu Item' do
      allow(Sidebars::MenuItem).to receive(:new).and_return(menu_item)
      allow(menu_bar).to receive(:serialize_as_menu_item_args).and_return({})

      subject.transform_old_menus(current_menus, menu_bar)

      expect(menu_foo.renderable_items).to eq([existing_item, menu_item])
    end

    it 'drops "solo" top-level Menu entries, if they serialize to nil' do
      allow(Sidebars::MenuItem).to receive(:new).and_return(menu_item)
      allow(menu_bar).to receive(:serialize_as_menu_item_args).and_return(nil)

      subject.transform_old_menus(current_menus, menu_bar)

      expect(menu_foo.renderable_items).to eq([existing_item])
    end
  end
end
