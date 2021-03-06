require "spec_helper"
require "mobility/plugins/locale_accessors"

describe Mobility::Plugins::LocaleAccessors do
  describe "when included into a class" do
    let(:base_model_class) do
      Class.new do
        def title(**_); end
        def title?(**_); end
        def title=(_value, **_); end
      end
    end

    context "with locales set" do
      let(:model_class) do
        base_model_class.include described_class.new(:title, locales: [:cz, :de, :'pt-BR'])
      end

      it_behaves_like "locale accessor", :title, :cz
      it_behaves_like "locale accessor", :title, :de
      it_behaves_like "locale accessor", :title, :'pt-BR'

      it "raises NoMethodError if locale not in locales" do
        instance = model_class.new
        aggregate_failures do
          expect { instance.title_en }.to raise_error(NoMethodError)
          expect { instance.title_en? }.to raise_error(NoMethodError)
          expect { instance.send(:title_en=, "value", {}) }.to raise_error(NoMethodError)
        end
      end

      it "warns locale option will be ignored if called with locale" do
        instance = model_class.new
        warning_message = /locale passed as option to locale accessor will be ignored/
        expect(instance).to receive(:title).with(locale: :cz).and_return("foo")
        expect { expect(instance.title_cz(locale: :en)).to eq("foo") }.to output(warning_message).to_stderr
        expect(instance).to receive(:title?).with(locale: :cz).and_return(true)
        expect { expect(instance.title_cz?(locale: :en)).to eq(true) }.to output(warning_message).to_stderr
        expect(instance).to receive(:title=).with("new foo", locale: :cz)
        expect { instance.send(:title_cz=, "new foo", locale: :en)}.to output(warning_message).to_stderr
      end
    end

    describe "super: true" do
      it "calls super of locale accessor method" do
        spy = double("model")
        mod = Module.new do
          define_method :title_en do
            spy.title_en
          end
          define_method :title_en? do
            spy.title_en?
          end
          define_method :title_en= do |value|
            spy.title_en = value
          end
        end
        base_model_class.include mod
        base_model_class.include described_class.new(:title, locales: [:en])

        instance = base_model_class.new

        aggregate_failures do
          expect(spy).to receive(:title_en).and_return("model foo")
          instance.title_en(super: true)

          expect(spy).to receive(:title_en?).and_return(true)
          instance.title_en?(super: true)

          expect(spy).to receive(:title_en=).with("model foo")
          instance.send(:title_en=, "model foo", super: true)
        end
      end
    end
  end

  describe ".apply" do
    let(:attributes) { instance_double(Mobility::Attributes, model_class: model_class, names: ["title"]) }
    let(:model_class) { Class.new }
    let(:locale_accessors) { instance_double(described_class) }

    context "option value is true" do
      it "includes instance of LocaleAccessors into attributes class with I18n.available_locales" do
        expect(described_class).to receive(:new).with("title", locales: I18n.available_locales).and_return(locale_accessors)
        expect(model_class).to receive(:include).with(locale_accessors)
        described_class.apply(attributes, true)
      end
    end

    context "option value is array of locales" do
      it "includes instance of LocaleAccessors into attributes class with array of locales" do
        expect(described_class).to receive(:new).with("title", locales: [:en, :fr]).and_return(locale_accessors)
        expect(model_class).to receive(:include).with(locale_accessors)
        described_class.apply(attributes, [:en, :fr])
      end
    end

    context "option value is falsey" do
      it "does not include instance of LocaleAccessors into attributes class" do
        expect(model_class).not_to receive(:include)
        described_class.apply(attributes, false)
        described_class.apply(attributes, nil)
      end
    end
  end
end
