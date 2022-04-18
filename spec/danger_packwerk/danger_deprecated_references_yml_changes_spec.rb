require 'spec_helper'

module DangerPackwerk
  RSpec.describe DangerDeprecatedReferencesYmlChanges do
    describe '#check' do
      let(:danger_deprecated_references_yml_changes) { dangerfile.deprecated_references_yml_changes }
      let(:plugin) { danger_deprecated_references_yml_changes }
      let(:slack_notifier) do
        double(notify_slack: true)
      end

      subject do
        danger_deprecated_references_yml_changes.check(
          before_comment: lambda do |violation_diff, changed_deprecated_references_ymls|
            diff_json = {
              privacy: { plus: violation_diff.added_violations.count(&:privacy?), minus: violation_diff.removed_violations.count(&:privacy?) },
              dependency: { plus: violation_diff.added_violations.count(&:dependency?), minus: violation_diff.removed_violations.count(&:dependency?) }
            }
            slack_notifier.notify_slack(diff_json, changed_deprecated_references_ymls)
          end
        )
      end

      let(:some_pack_deprecated_references_before) { nil }

      before do
        allow(danger_deprecated_references_yml_changes.git).to receive(:diff).and_return({ 'packs/some_pack/deprecated_references.yml' => double(patch: 'some_fancy_patch') })

        # After we make the system call to apply the inverse of the deletion patch, we should expect the file
        # to be present again, so we write it here as a means of stubbing out that call to `git`.
        allow(Open3).to receive(:capture3) do |system_call|
          expect(system_call).to include('git apply --reverse ')
          patch_file = system_call.gsub('git apply --reverse ', '')
          expect(File.read(patch_file)).to eq "some_fancy_patch\n"
          some_pack_deprecated_references_before
        end
      end

      context 'when no deprecated_references.yml files have been added or modified' do
        let(:modified_files) { ['app/models/employee.rb'] }
        let(:added_files) { ['spec/models/employee_spec.rb'] }

        it 'does not send any messages' do
          subject
          expect(dangerfile.status_report[:warnings]).to be_empty
          expect(dangerfile.status_report[:errors]).to be_empty
          expect(dangerfile.status_report[:messages]).to be_empty
        end

        it 'calls notify sslack' do
          expect(slack_notifier).to receive(:notify_slack)
          subject
        end
      end

      context 'a deprecated_references.yml file is added (i.e. a pack has its first violation)' do
        let(:added_files) do
          [
            write_file('packs/some_pack/deprecated_references.yml', <<~YML.strip)
              ---
              packs/some_other_pack:
                "OtherPackClass":
                  violations:
                  - privacy
                  - dependency
                  files:
                  - packs/some_pack/some_class.rb
            YML
          ]
        end

        it 'calls the before comment input proc' do
          expect(slack_notifier).to receive(:notify_slack).with(
            { dependency: { minus: 0, plus: 1 }, privacy: { minus: 0, plus: 1 } },
            ['packs/some_pack/deprecated_references.yml']
          )

          subject
        end

        context 'default formatter is used' do
          it 'displays a markdown with a reasonable message' do
            subject
            expect(dangerfile.status_report[:warnings]).to be_empty
            expect(dangerfile.status_report[:errors]).to be_empty
            actual_markdowns = dangerfile.status_report[:markdowns]
            expect(actual_markdowns.count).to eq 1
            actual_markdown = actual_markdowns.first
            expected = <<~EXPECTED
              Hi! It looks like the pack defining `OtherPackClass` considers this private API, and it's also not in the referencing pack's list of dependencies.
              We noticed you ran `bin/packwerk update-deprecations`. Make sure to read through [the docs](https://github.com/Shopify/packwerk/blob/b647594f93c8922c038255a7aaca125d391a1fbf/docs/new_violation_flow_chart.pdf) for other ways to resolve. Could you add some context as a reply here about why we needed to add these violations?
            EXPECTED

            expect(actual_markdown.message).to eq expected
            expect(actual_markdown.line).to eq 3
            expect(actual_markdown.file).to eq 'packs/some_pack/deprecated_references.yml'
            expect(actual_markdown.type).to eq :markdown
          end
        end

        context 'a offenses formatter is passed in' do
          let(:added_offenses_formatter) do
            lambda do |added_violations|
              <<~MESSAGE
                There are #{added_violations.count} new violations,
                with class_names #{added_violations.map(&:class_name).uniq.sort},
                with to_package_names #{added_violations.map(&:to_package_name).uniq.sort},
                with types #{added_violations.map(&:type).sort},
              MESSAGE
            end
          end

          subject do
            danger_deprecated_references_yml_changes.check(
              added_offenses_formatter: added_offenses_formatter,
              before_comment: lambda do |_violation_diff, changed_deprecated_references_ymls|
                slack_notifier.notify_slack(changed_deprecated_references_ymls)
              end
            )
          end

          it 'displays a markdown using the passed in offenses formatter' do
            subject
            expect(dangerfile.status_report[:warnings]).to be_empty
            expect(dangerfile.status_report[:errors]).to be_empty
            actual_markdowns = dangerfile.status_report[:markdowns]
            expect(actual_markdowns.count).to eq 1
            actual_markdown = actual_markdowns.first
            expected = <<~EXPECTED
              There are 2 new violations,
              with class_names ["OtherPackClass"],
              with to_package_names ["packs/some_other_pack"],
              with types ["dependency", "privacy"],
            EXPECTED

            expect(actual_markdown.message).to eq expected
            expect(actual_markdown.line).to eq 3
            expect(actual_markdown.file).to eq 'packs/some_pack/deprecated_references.yml'
            expect(actual_markdown.type).to eq :markdown
          end
        end
      end

      context 'a deprecated_references.yml file is deleted (i.e. a pack has all violations removed)' do
        let(:deleted_files) { ['packs/some_pack/deprecated_references.yml'] }
        let(:some_pack_deprecated_references_before) do
          write_file('packs/some_pack/deprecated_references.yml', <<~YML.strip)
            ---
            packs/some_other_pack:
              "OtherPackClass":
                violations:
                - dependency
                - privacy
                files:
                - packs/some_pack/some_class.rb
          YML
        end

        it 'calls the before comment input proc' do
          expect(slack_notifier).to receive(:notify_slack).with(
            { dependency: { minus: 1, plus: 0 }, privacy: { minus: 1, plus: 0 } },
            ['packs/some_pack/deprecated_references.yml']
          )

          subject
        end

        it 'does not display a markdown message' do
          subject
          expect(dangerfile.status_report[:warnings]).to be_empty
          expect(dangerfile.status_report[:errors]).to be_empty
          actual_markdowns = dangerfile.status_report[:markdowns]
          expect(actual_markdowns.count).to eq 0
        end
      end

      context 'a deprecated_refrences.yml file is modified to remove some, but not all, violations' do
        let(:modified_files) do
          [
            write_file('packs/some_pack/deprecated_references.yml', <<~YML.strip)
              ---
              packs/some_other_pack:
                "OtherPackClass":
                  violations:
                  - privacy
                  files:
                  - packs/some_pack/some_class.rb
            YML
          ]
        end

        let(:some_pack_deprecated_references_before) do
          write_file('packs/some_pack/deprecated_references.yml', <<~YML.strip)
            ---
            packs/some_other_pack:
              "OtherPackClass":
                violations:
                - privacy
                files:
                - packs/some_pack/some_class.rb
              "OtherPackClass2":
                violations:
                - dependency
                - privacy
                files:
                - packs/some_pack/some_class2.rb
          YML
        end

        it 'calls the before comment input proc' do
          expect(slack_notifier).to receive(:notify_slack).with(
            { dependency: { minus: 1, plus: 0 }, privacy: { minus: 1, plus: 0 } },
            ['packs/some_pack/deprecated_references.yml']
          )

          subject
        end

        it 'does not display a markdown message' do
          subject
          expect(dangerfile.status_report[:warnings]).to be_empty
          expect(dangerfile.status_report[:errors]).to be_empty
          actual_markdowns = dangerfile.status_report[:markdowns]
          expect(actual_markdowns.count).to eq 0
        end
      end

      context 'a deprecated_refrences.yml file is modified to add a new violation against a new constant in an existing file' do
        let(:modified_files) do
          [
            write_file('packs/some_pack/deprecated_references.yml', <<~YML.strip)
              ---
              packs/some_other_pack:
                "OtherPackClass":
                  violations:
                  - privacy
                  files:
                  - packs/some_pack/some_class.rb
                "OtherPackClass2":
                  violations:
                  - privacy
                  - dependency
                  files:
                  - packs/some_pack/some_class.rb
            YML
          ]
        end

        let(:some_pack_deprecated_references_before) do
          write_file('packs/some_pack/deprecated_references.yml', <<~YML.strip)
            ---
            packs/some_other_pack:
              "OtherPackClass":
                violations:
                - privacy
                files:
                - packs/some_pack/some_class.rb
          YML
        end

        it 'calls the before comment input proc' do
          expect(slack_notifier).to receive(:notify_slack).with(
            { dependency: { minus: 0, plus: 1 }, privacy: { minus: 0, plus: 1 } },
            ['packs/some_pack/deprecated_references.yml']
          )

          subject
        end

        it 'displays a markdown with a reasonable message' do
          subject
          expect(dangerfile.status_report[:warnings]).to be_empty
          expect(dangerfile.status_report[:errors]).to be_empty
          actual_markdowns = dangerfile.status_report[:markdowns]
          expect(actual_markdowns.count).to eq 1
          actual_markdown = actual_markdowns.first
          expected = <<~EXPECTED
            Hi! It looks like the pack defining `OtherPackClass2` considers this private API, and it's also not in the referencing pack's list of dependencies.
            We noticed you ran `bin/packwerk update-deprecations`. Make sure to read through [the docs](https://github.com/Shopify/packwerk/blob/b647594f93c8922c038255a7aaca125d391a1fbf/docs/new_violation_flow_chart.pdf) for other ways to resolve. Could you add some context as a reply here about why we needed to add these violations?
          EXPECTED

          expect(actual_markdown.message).to eq expected
          expect(actual_markdown.line).to eq 8
          expect(actual_markdown.file).to eq 'packs/some_pack/deprecated_references.yml'
          expect(actual_markdown.type).to eq :markdown
        end
      end

      context 'a deprecated_refrences.yml file is modified to add a new reference against an existing constant in an existing file' do
        let(:modified_files) do
          [
            write_file('packs/some_pack/deprecated_references.yml', <<~YML.strip)
              ---
              packs/some_other_pack:
                "OtherPackClass":
                  violations:
                  - privacy
                  files:
                  - packs/some_pack/some_class.rb
                  - packs/some_pack/some_other_class.rb
            YML
          ]
        end

        let(:some_pack_deprecated_references_before) do
          write_file('packs/some_pack/deprecated_references.yml', <<~YML.strip)
            ---
            packs/some_other_pack:
              "OtherPackClass":
                violations:
                - privacy
                files:
                - packs/some_pack/some_class.rb
          YML
        end

        it 'calls the before comment input proc' do
          expect(slack_notifier).to receive(:notify_slack).with(
            { dependency: { minus: 0, plus: 0 }, privacy: { minus: 0, plus: 1 } },
            ['packs/some_pack/deprecated_references.yml']
          )

          subject
        end

        it 'displays a markdown with a reasonable message' do
          subject
          expect(dangerfile.status_report[:warnings]).to be_empty
          expect(dangerfile.status_report[:errors]).to be_empty
          actual_markdowns = dangerfile.status_report[:markdowns]
          expect(actual_markdowns.count).to eq 1
          actual_markdown = actual_markdowns.first
          expected = <<~EXPECTED
            Hi! It looks like the pack defining `OtherPackClass` considers this private API.
            We noticed you ran `bin/packwerk update-deprecations`. Make sure to read through [the docs](https://github.com/Shopify/packwerk/blob/b647594f93c8922c038255a7aaca125d391a1fbf/docs/new_violation_flow_chart.pdf) for other ways to resolve. Could you add some context as a reply here about why we needed to add this violation?
          EXPECTED

          expect(actual_markdown.message).to eq expected
          expect(actual_markdown.line).to eq 3
          expect(actual_markdown.file).to eq 'packs/some_pack/deprecated_references.yml'
          expect(actual_markdown.type).to eq :markdown
        end
      end

      context 'a deprecated_refrences.yml file is modified to add a reference (that already exists in `deprecated_references.yml`) against an existing constant in an existing file' do
        let(:modified_files) do
          [
            write_file('packs/some_pack/deprecated_references.yml', <<~YML.strip)
              ---
              packs/some_other_pack:
                "OtherPackClass":
                  violations:
                  - privacy
                  files:
                  - packs/some_pack/some_class.rb
                  - packs/some_pack/some_other_class.rb
                "SomeOtherPackClass":
                  violations:
                  - privacy
                  files:
                  - packs/some_pack/some_class.rb
                  - packs/some_pack/some_other_class.rb
            YML
          ]
        end

        let(:some_pack_deprecated_references_before) do
          write_file('packs/some_pack/deprecated_references.yml', <<~YML.strip)
            ---
            packs/some_other_pack:
              "OtherPackClass":
                violations:
                - privacy
                files:
                - packs/some_pack/some_class.rb
                - packs/some_pack/some_other_class.rb
              "SomeOtherPackClass":
                violations:
                - privacy
                files:
                - packs/some_pack/some_class.rb
          YML
        end

        it 'calls the before comment input proc' do
          expect(slack_notifier).to receive(:notify_slack).with(
            { dependency: { minus: 0, plus: 0 }, privacy: { minus: 0, plus: 1 } },
            ['packs/some_pack/deprecated_references.yml']
          )

          subject
        end

        it 'displays a markdown with a reasonable message' do
          subject
          expect(dangerfile.status_report[:warnings]).to be_empty
          expect(dangerfile.status_report[:errors]).to be_empty
          actual_markdowns = dangerfile.status_report[:markdowns]
          expect(actual_markdowns.count).to eq 1
          actual_markdown = actual_markdowns.first
          expected = <<~EXPECTED
            Hi! It looks like the pack defining `SomeOtherPackClass` considers this private API.
            We noticed you ran `bin/packwerk update-deprecations`. Make sure to read through [the docs](https://github.com/Shopify/packwerk/blob/b647594f93c8922c038255a7aaca125d391a1fbf/docs/new_violation_flow_chart.pdf) for other ways to resolve. Could you add some context as a reply here about why we needed to add this violation?
          EXPECTED

          expect(actual_markdown.message).to eq expected
          expect(actual_markdown.line).to eq 9
          expect(actual_markdown.file).to eq 'packs/some_pack/deprecated_references.yml'
          expect(actual_markdown.type).to eq :markdown
        end
      end

      context 'a deprecated_refrences.yml file is modified to change violations in many files' do
        let(:modified_files) do
          [
            write_file('packs/some_pack/deprecated_references.yml', <<~YML.strip)
              ---
              packs/some_other_pack:
                "OtherPackClass":
                  violations:
                  - privacy
                  - dependency
                  files:
                  - packs/some_pack/some_class.rb
            YML
          ]
        end

        let(:some_pack_deprecated_references_before) do
          write_file('packs/some_pack/deprecated_references.yml', <<~YML.strip)
            ---
            packs/some_other_pack:
              "OtherPackClass":
                violations:
                - privacy
                files:
                - packs/some_pack/some_class.rb
                - packs/some_pack/some_class2.rb
                - packs/some_pack/some_class3.rb
                - packs/some_pack/some_class4.rb
                - packs/some_pack/some_class5.rb
                - packs/some_pack/some_class6.rb
                - packs/some_pack/some_class7.rb
              "OtherPackClass2":
                violations:
                - dependency
                - privacy
                files:
                - packs/some_pack/some_class2.rb
                - packs/some_pack/some_class3.rb
                - packs/some_pack/some_class4.rb
                - packs/some_pack/some_class5.rb
                - packs/some_pack/some_class6.rb
                - packs/some_pack/some_class7.rb

          YML
        end

        it 'calls the before comment input proc' do
          expect(slack_notifier).to receive(:notify_slack).with(
            { dependency: { minus: 6, plus: 1 }, privacy: { minus: 12, plus: 0 } },
            ['packs/some_pack/deprecated_references.yml']
          )

          subject
        end

        it 'displays a markdown with a reasonable message' do
          subject
          expect(dangerfile.status_report[:warnings]).to be_empty
          expect(dangerfile.status_report[:errors]).to be_empty
          actual_markdowns = dangerfile.status_report[:markdowns]
          expect(actual_markdowns.count).to eq 1
          actual_markdown = actual_markdowns.first
          expected = <<~EXPECTED
            Hi! It looks like the pack defining `OtherPackClass` is not in the referencing pack's list of dependencies.
            We noticed you ran `bin/packwerk update-deprecations`. Make sure to read through [the docs](https://github.com/Shopify/packwerk/blob/b647594f93c8922c038255a7aaca125d391a1fbf/docs/new_violation_flow_chart.pdf) for other ways to resolve. Could you add some context as a reply here about why we needed to add this violation?
          EXPECTED

          expect(actual_markdown.message).to eq expected
          expect(actual_markdown.line).to eq 3
          expect(actual_markdown.file).to eq 'packs/some_pack/deprecated_references.yml'
          expect(actual_markdown.type).to eq :markdown
        end
      end

      context 'a deprecated_refrences.yml file is modified to add 30 and remove 15 violations' do
        let(:modified_files) do
          [
            write_file('packs/some_pack/deprecated_references.yml', <<~YML.strip)
              ---
              packs/some_other_pack:
                "OtherPackClass":
                  violations:
                  - privacy
                  - dependency
                  files:
                  - packs/some_pack/some_class1.rb
                  - packs/some_pack/some_class2.rb
                  - packs/some_pack/some_class3.rb
                  - packs/some_pack/some_class4.rb
                  - packs/some_pack/some_class5.rb
                  - packs/some_pack/some_class6.rb
                  - packs/some_pack/some_class7.rb
                  - packs/some_pack/some_class8.rb
                  - packs/some_pack/some_class9.rb
                  - packs/some_pack/some_class10.rb
                  - packs/some_pack/some_class11.rb
                  - packs/some_pack/some_class12.rb
                  - packs/some_pack/some_class13.rb
                  - packs/some_pack/some_class14.rb
                  - packs/some_pack/some_class15.rb
            YML
          ]
        end

        let(:some_pack_deprecated_references_before) do
          write_file('packs/some_pack/deprecated_references.yml', <<~YML.strip)
            ---
            packs/some_other_pack:
              "OtherPackClass":
                violations:
                - privacy
                files:
                - packs/some_pack/some_class1.rb
                - packs/some_pack/some_class2.rb
                - packs/some_pack/some_class3.rb
                - packs/some_pack/some_class4.rb
                - packs/some_pack/some_class5.rb
                - packs/some_pack/some_class6.rb
                - packs/some_pack/some_class7.rb
                - packs/some_pack/some_class8.rb
                - packs/some_pack/some_class9.rb
                - packs/some_pack/some_class10.rb
                - packs/some_pack/some_class11.rb
                - packs/some_pack/some_class12.rb
                - packs/some_pack/some_class13.rb
                - packs/some_pack/some_class14.rb
                - packs/some_pack/some_class15.rb
              "AnotherPackClass":
                violations:
                - privacy
                - dependency
                files:
                - packs/some_pack/some_other_class1.rb
                - packs/some_pack/some_other_class2.rb
                - packs/some_pack/some_other_class3.rb
                - packs/some_pack/some_other_class4.rb
                - packs/some_pack/some_other_class5.rb
                - packs/some_pack/some_other_class6.rb
                - packs/some_pack/some_other_class7.rb
                - packs/some_pack/some_other_class8.rb
                - packs/some_pack/some_other_class9.rb
                - packs/some_pack/some_other_class10.rb
                - packs/some_pack/some_other_class11.rb
                - packs/some_pack/some_other_class12.rb
                - packs/some_pack/some_other_class13.rb
                - packs/some_pack/some_other_class14.rb
                - packs/some_pack/some_other_class15.rb
          YML
        end

        it 'calls the before comment input proc' do
          expect(slack_notifier).to receive(:notify_slack).with(
            { dependency: { minus: 15, plus: 15 }, privacy: { minus: 15, plus: 0 } },
            ['packs/some_pack/deprecated_references.yml']
          )

          subject
        end

        it 'displays a markdown with a reasonable message' do
          subject
          expect(dangerfile.status_report[:warnings]).to be_empty
          expect(dangerfile.status_report[:errors]).to be_empty
          actual_markdowns = dangerfile.status_report[:markdowns]
          expect(actual_markdowns.count).to eq 1
          actual_markdown = actual_markdowns.first
          expected = <<~EXPECTED
            Hi! It looks like the pack defining `OtherPackClass` is not in the referencing pack's list of dependencies.
            We noticed you ran `bin/packwerk update-deprecations`. Make sure to read through [the docs](https://github.com/Shopify/packwerk/blob/b647594f93c8922c038255a7aaca125d391a1fbf/docs/new_violation_flow_chart.pdf) for other ways to resolve. Could you add some context as a reply here about why we needed to add these violations?
          EXPECTED

          expect(actual_markdown.message).to eq expected
          expect(actual_markdown.line).to eq 3
          expect(actual_markdown.file).to eq 'packs/some_pack/deprecated_references.yml'
          expect(actual_markdown.type).to eq :markdown
        end
      end
    end
  end
end
