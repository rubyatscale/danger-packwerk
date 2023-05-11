require 'spec_helper'

module DangerPackwerk
  RSpec.describe DangerPackageTodoYmlChanges do
    describe '#check' do
      let(:danger_package_todo_yml_changes) { dangerfile.package_todo_yml_changes }
      let(:plugin) { danger_package_todo_yml_changes }
      let(:slack_notifier) do
        double(notify_slack: true)
      end

      let(:load_paths) do
        {
          'packs/some_pack' => 'Object'
        }
      end

      let(:before_comment) do
        lambda do |violation_diff, changed_package_todo_ymls|
          diff_json = {
            privacy: { plus: violation_diff.added_violations.count(&:privacy?), minus: violation_diff.removed_violations.count(&:privacy?) },
            dependency: { plus: violation_diff.added_violations.count(&:dependency?), minus: violation_diff.removed_violations.count(&:dependency?) }
          }
          slack_notifier.notify_slack(diff_json, changed_package_todo_ymls)
        end
      end

      subject do
        danger_package_todo_yml_changes.check(
          before_comment: before_comment
        )
      end

      let(:some_pack_package_todo_before) { nil }
      let(:diff_double) { sorbet_double(Git::Diff::DiffFile) }

      before do
        write_file('packs/some_pack/package.yml', <<~YML)
          enforce_privacy: true
          enforce_dependencies: true
        YML

        write_file('packs/some_other_pack/package.yml', <<~YML)
          enforce_privacy: true
          enforce_dependencies: true
        YML

        write_file('package.yml', <<~YML)
          enforce_privacy: true
          enforce_dependencies: true
        YML

        allow(diff_double).to receive(:patch).and_return('some_fancy_patch')
        allow(danger_package_todo_yml_changes.git).to receive(:diff).and_return({ 'packs/some_pack/package_todo.yml' => diff_double })

        # After we make the system call to apply the inverse of the deletion patch, we should expect the file
        # to be present again, so we write it here as a means of stubbing out that call to `git`.
        allow(Open3).to receive(:capture3) do |system_call|
          expect(system_call).to include('git apply --reverse ')
          patch_file = system_call.gsub('git apply --reverse ', '')
          expect(File.read(patch_file)).to eq "some_fancy_patch\n"
          some_pack_package_todo_before
        end

        # These paths need to exist for ConstantResolver
        [
          'packs/some_pack/some_class.rb',
          'packs/some_pack/some_other_class.rb',
          'packs/some_pack/some_file.rb',
          'packs/some_pack/some_class_with_new_name.rb',
          'packs/some_pack/some_class_with_old_name.rb'
        ].each { |path| write_file(path) }
        allow(Packwerk::RailsLoadPaths).to receive(:for).and_return(load_paths)
      end

      context 'when no package_todo.yml files have been added or modified' do
        let(:modified_files) { ['app/models/employee.rb'] }
        let(:added_files) { ['spec/models/employee_spec.rb'] }

        it 'does not send any messages' do
          subject
          expect(dangerfile).to produce_no_danger_messages
        end

        it 'calls notify sslack' do
          expect(slack_notifier).to receive(:notify_slack)
          subject
        end
      end

      context 'a package_todo.yml file is added (i.e. a pack has its first violation)' do
        let(:added_files) do
          [
            write_file('packs/some_pack/package_todo.yml', <<~YML.strip)
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
            ['packs/some_pack/package_todo.yml']
          )

          subject
        end

        context 'default formatter is used' do
          it 'displays a markdown with a reasonable message' do
            subject

            expect('packs/some_pack/package_todo.yml').to contain_inline_markdown(
              <<~EXPECTED
                ---
                packs/some_other_pack:
                  "OtherPackClass":
                    violations:
                    - privacy
                    - dependency
                    files:
                    - packs/some_pack/some_class.rb
                ==================== DANGER_START
                Hi again! It looks like `OtherPackClass` is private API of `packs/some_other_pack`, which is also not in `packs/some_pack`'s list of dependencies.
                We noticed you ran `bin/packwerk update-todo`. Check out [the docs](https://github.com/Shopify/packwerk/blob/main/RESOLVING_VIOLATIONS.md) to see other ways to resolve violations.

                - Could you add some context as a reply here about why we needed to add these violations?

                ==================== DANGER_END
              EXPECTED
            ).and_nothing_else
          end
        end

        context 'a offenses formatter is passed in' do
          let(:offenses_formatter) do
            Class.new do
              include Update::OffensesFormatter

              def format_offenses(added_violations, repo_link, org_name)
                <<~MESSAGE
                  There are #{added_violations.count} new violations,
                  with class_names #{added_violations.map(&:class_name).uniq.sort},
                  with to_package_names #{added_violations.map(&:to_package_name).uniq.sort},
                  with types #{added_violations.map(&:type).sort},
                MESSAGE
              end
            end
          end

          subject do
            danger_package_todo_yml_changes.check(
              offenses_formatter: offenses_formatter.new,
              before_comment: lambda do |_violation_diff, changed_package_todo_ymls|
                slack_notifier.notify_slack(changed_package_todo_ymls)
              end
            )
          end

          it 'displays a markdown using the passed in offenses formatter' do
            subject

            expect('packs/some_pack/package_todo.yml').to contain_inline_markdown(
              <<~EXPECTED
                ---
                packs/some_other_pack:
                  "OtherPackClass":
                    violations:
                    - privacy
                    - dependency
                    files:
                    - packs/some_pack/some_class.rb
                ==================== DANGER_START
                There are 2 new violations,
                with class_names ["OtherPackClass"],
                with to_package_names ["packs/some_other_pack"],
                with types ["dependency", "privacy"],
                ==================== DANGER_END
              EXPECTED
            ).and_nothing_else
          end
        end
      end

      context 'a package_todo.yml file is deleted (i.e. a pack has all violations removed)' do
        let(:deleted_files) { ['packs/some_pack/package_todo.yml'] }
        let(:some_pack_package_todo_before) do
          write_file('packs/some_pack/package_todo.yml', <<~YML.strip)
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
            ['packs/some_pack/package_todo.yml']
          )

          subject
        end

        it 'does not display a markdown message' do
          subject
          expect(dangerfile).to produce_no_danger_messages
        end
      end

      context 'a package_todo.yml file is modified to remove some, but not all, violations' do
        let(:modified_files) do
          [
            write_file('packs/some_pack/package_todo.yml', <<~YML.strip)
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

        let(:some_pack_package_todo_before) do
          write_file('packs/some_pack/package_todo.yml', <<~YML.strip)
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
            ['packs/some_pack/package_todo.yml']
          )

          subject
        end

        it 'does not display a markdown message' do
          subject
          expect(dangerfile).to produce_no_danger_messages
        end
      end

      context 'a package_todo.yml file is modified to add a new violation against a new constant in an existing file' do
        let(:modified_files) do
          [
            write_file('packs/some_pack/package_todo.yml', <<~YML.strip)
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

        let(:some_pack_package_todo_before) do
          write_file('packs/some_pack/package_todo.yml', <<~YML.strip)
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
            ['packs/some_pack/package_todo.yml']
          )

          subject
        end

        it 'displays a markdown with a reasonable message' do
          subject

          expect('packs/some_pack/package_todo.yml').to contain_inline_markdown(
            <<~EXPECTED
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
              ==================== DANGER_START
              Hi again! It looks like `OtherPackClass2` is private API of `packs/some_other_pack`, which is also not in `packs/some_pack`'s list of dependencies.
              We noticed you ran `bin/packwerk update-todo`. Check out [the docs](https://github.com/Shopify/packwerk/blob/main/RESOLVING_VIOLATIONS.md) to see other ways to resolve violations.

              - Could you add some context as a reply here about why we needed to add these violations?

              ==================== DANGER_END
            EXPECTED
          ).and_nothing_else
        end
      end

      context 'a package_todo.yml file is modified to add a new reference against an existing constant in an existing file' do
        let(:modified_files) do
          [
            write_file('packs/some_pack/package_todo.yml', <<~YML.strip)
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

        let(:some_pack_package_todo_before) do
          write_file('packs/some_pack/package_todo.yml', <<~YML.strip)
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
            ['packs/some_pack/package_todo.yml']
          )

          subject
        end

        it 'displays a markdown with a reasonable message' do
          subject

          expect('packs/some_pack/package_todo.yml').to contain_inline_markdown(
            <<~EXPECTED
              ---
              packs/some_other_pack:
                "OtherPackClass":
                  violations:
                  - privacy
                  files:
                  - packs/some_pack/some_class.rb
                  - packs/some_pack/some_other_class.rb
              ==================== DANGER_START
              Hi again! It looks like `OtherPackClass` is private API of `packs/some_other_pack`.
              We noticed you ran `bin/packwerk update-todo`. Check out [the docs](https://github.com/Shopify/packwerk/blob/main/RESOLVING_VIOLATIONS.md) to see other ways to resolve violations.

              - Could you add some context as a reply here about why we needed to add this violation?

              ==================== DANGER_END
            EXPECTED
          ).and_nothing_else
        end
      end

      context 'a package_todo.yml file is modified to add another violation on a file with an existing violation' do
        let(:modified_files) do
          [
            write_file('packs/some_pack/package_todo.yml', <<~YML.strip)
              ---
              packs/some_other_pack:
                "ABCClass":
                  violations:
                  - privacy
                  files:
                  - packs/some_pack/some_class.rb
                  - packs/some_pack/some_other_class.rb
                "XYZModule":
                  violations:
                  - privacy
                  files:
                  - packs/some_pack/some_class.rb
                  - packs/some_pack/some_other_class.rb
            YML
          ]
        end

        let(:some_pack_package_todo_before) do
          write_file('packs/some_pack/package_todo.yml', <<~YML.strip)
            ---
            packs/some_other_pack:
              "ABCClass":
                violations:
                - privacy
                files:
                - packs/some_pack/some_class.rb
                - packs/some_pack/some_other_class.rb
              "XYZModule":
                violations:
                - privacy
                files:
                - packs/some_pack/some_class.rb
          YML
        end

        it 'calls the before comment input proc' do
          expect(slack_notifier).to receive(:notify_slack).with(
            { dependency: { minus: 0, plus: 0 }, privacy: { minus: 0, plus: 1 } },
            ['packs/some_pack/package_todo.yml']
          )

          subject
        end

        it 'displays a markdown with a reasonable message' do
          subject

          expect('packs/some_pack/package_todo.yml').to contain_inline_markdown(
            <<~EXPECTED
              ---
              packs/some_other_pack:
                "ABCClass":
                  violations:
                  - privacy
                  files:
                  - packs/some_pack/some_class.rb
                  - packs/some_pack/some_other_class.rb
                "XYZModule":
                  violations:
                  - privacy
                  files:
                  - packs/some_pack/some_class.rb
                  - packs/some_pack/some_other_class.rb
              ==================== DANGER_START
              Hi again! It looks like `XYZModule` is private API of `packs/some_other_pack`.
              We noticed you ran `bin/packwerk update-todo`. Check out [the docs](https://github.com/Shopify/packwerk/blob/main/RESOLVING_VIOLATIONS.md) to see other ways to resolve violations.

              - Could you add some context as a reply here about why we needed to add this violation?

              ==================== DANGER_END
            EXPECTED
          ).and_nothing_else
        end
      end

      context 'a package_todo.yml file is modified to add another violation on a file with an existing violation, and the constants have clashing names' do
        let(:modified_files) do
          [
            write_file('packs/some_pack/package_todo.yml', <<~YML.strip)
              ---
              packs/some_other_pack:
                "::TopLevelModule::Helpers::MyHelper":
                  violations:
                  - privacy
                  files:
                  - packs/some_pack/some_class.rb
                  - packs/some_pack/some_other_class.rb
                "::Helpers":
                  violations:
                  - privacy
                  files:
                  - packs/some_pack/some_class.rb
                  - packs/some_pack/some_other_class.rb
            YML
          ]
        end

        let(:some_pack_package_todo_before) do
          write_file('packs/some_pack/package_todo.yml', <<~YML.strip)
            ---
            packs/some_other_pack:
              "::TopLevelModule::Helpers::MyHelper":
                violations:
                - privacy
                files:
                - packs/some_pack/some_class.rb
                - packs/some_pack/some_other_class.rb
              "::Helpers":
                violations:
                - privacy
                files:
                - packs/some_pack/some_class.rb
          YML
        end

        it 'calls the before comment input proc' do
          expect(slack_notifier).to receive(:notify_slack).with(
            { dependency: { minus: 0, plus: 0 }, privacy: { minus: 0, plus: 1 } },
            ['packs/some_pack/package_todo.yml']
          )

          subject
        end

        it 'displays a markdown with a reasonable message' do
          subject

          expect('packs/some_pack/package_todo.yml').to contain_inline_markdown(
            <<~EXPECTED
              ---
              packs/some_other_pack:
                "::TopLevelModule::Helpers::MyHelper":
                  violations:
                  - privacy
                  files:
                  - packs/some_pack/some_class.rb
                  - packs/some_pack/some_other_class.rb
                "::Helpers":
                  violations:
                  - privacy
                  files:
                  - packs/some_pack/some_class.rb
                  - packs/some_pack/some_other_class.rb
              ==================== DANGER_START
              Hi again! It looks like `Helpers` is private API of `packs/some_other_pack`.
              We noticed you ran `bin/packwerk update-todo`. Check out [the docs](https://github.com/Shopify/packwerk/blob/main/RESOLVING_VIOLATIONS.md) to see other ways to resolve violations.

              - Could you add some context as a reply here about why we needed to add this violation?

              ==================== DANGER_END
            EXPECTED
          ).and_nothing_else
        end
      end

      context 'a package_todo.yml file is modified to change violations in many files' do
        let(:modified_files) do
          [
            write_file('packs/some_pack/package_todo.yml', <<~YML.strip)
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

        let(:some_pack_package_todo_before) do
          write_file('packs/some_pack/package_todo.yml', <<~YML.strip)
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
            ['packs/some_pack/package_todo.yml']
          )

          subject
        end

        it 'displays a markdown with a reasonable message' do
          subject

          expect('packs/some_pack/package_todo.yml').to contain_inline_markdown(
            <<~EXPECTED
              ---
              packs/some_other_pack:
                "OtherPackClass":
                  violations:
                  - privacy
                  - dependency
                  files:
                  - packs/some_pack/some_class.rb
              ==================== DANGER_START
              Hi again! It looks like `OtherPackClass` belongs to `packs/some_other_pack`, which is not in `packs/some_pack`'s list of dependencies.
              We noticed you ran `bin/packwerk update-todo`. Check out [the docs](https://github.com/Shopify/packwerk/blob/main/RESOLVING_VIOLATIONS.md) to see other ways to resolve violations.

              - Could you add some context as a reply here about why we needed to add this violation?

              ==================== DANGER_END
            EXPECTED
          ).and_nothing_else
        end
      end

      context 'a package_todo.yml file is modified to add 30 and remove 15 violations' do
        let(:modified_files) do
          [
            write_file('packs/some_pack/package_todo.yml', <<~YML.strip)
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

        let(:some_pack_package_todo_before) do
          write_file('packs/some_pack/package_todo.yml', <<~YML.strip)
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
            ['packs/some_pack/package_todo.yml']
          )

          subject
        end

        it 'displays a markdown with a reasonable message' do
          subject

          expect('packs/some_pack/package_todo.yml').to contain_inline_markdown(
            <<~EXPECTED
              ---
              packs/some_other_pack:
                "OtherPackClass":
                  violations:
                  - privacy
                  - dependency
                  files:
                  - packs/some_pack/some_class1.rb
              ==================== DANGER_START
              Hi again! It looks like `OtherPackClass` belongs to `packs/some_other_pack`, which is not in `packs/some_pack`'s list of dependencies.
              We noticed you ran `bin/packwerk update-todo`. Check out [the docs](https://github.com/Shopify/packwerk/blob/main/RESOLVING_VIOLATIONS.md) to see other ways to resolve violations.

              - Could you add some context as a reply here about why we needed to add these violations?

              ==================== DANGER_END
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
            EXPECTED
          ).and_nothing_else
        end
      end

      context 'a package_todo.yml file using single quotes is modified' do
        let(:modified_files) do
          [
            write_file('packs/some_pack/package_todo.yml', <<~YML.strip)
              ---
              packs/some_other_pack:
                'OtherPackClass':
                  violations:
                  - privacy
                  files:
                  - packs/some_pack/some_class1.rb
                  - packs/some_pack/some_class2.rb
            YML
          ]
        end

        let(:some_pack_package_todo_before) do
          write_file('packs/some_pack/package_todo.yml', <<~YML.strip)
            ---
            packs/some_other_pack:
              'OtherPackClass':
                violations:
                - privacy
                files:
                - packs/some_pack/some_class1.rb
          YML
        end

        it 'calls the before comment input proc' do
          expect(slack_notifier).to receive(:notify_slack).with(
            { dependency: { minus: 0, plus: 0 }, privacy: { minus: 0, plus: 1 } },
            ['packs/some_pack/package_todo.yml']
          )

          subject
        end

        it 'displays a markdown with a reasonable message' do
          subject

          expect('packs/some_pack/package_todo.yml').to contain_inline_markdown(
            <<~EXPECTED
              ---
              packs/some_other_pack:
                'OtherPackClass':
                  violations:
                  - privacy
                  files:
                  - packs/some_pack/some_class1.rb
                  - packs/some_pack/some_class2.rb
              ==================== DANGER_START
              Hi again! It looks like `OtherPackClass` is private API of `packs/some_other_pack`.
              We noticed you ran `bin/packwerk update-todo`. Check out [the docs](https://github.com/Shopify/packwerk/blob/main/RESOLVING_VIOLATIONS.md) to see other ways to resolve violations.

              - Could you add some context as a reply here about why we needed to add this violation?

              ==================== DANGER_END
            EXPECTED
          ).and_nothing_else
        end
      end

      context 'a package_todo.yml file has been modified with files that have been renamed' do
        let(:renamed_files) do
          [
            {
              after: 'packs/some_pack/some_class_with_new_name.rb',
              before: 'packs/some_pack/some_class_with_old_name.rb'
            }
          ]
        end

        let(:modified_files) do
          [
            write_file('packs/some_pack/package_todo.yml', <<~YML.strip)
              ---
              packs/some_other_pack:
                "OtherPackClass":
                  violations:
                  - privacy
                  files:
                  - packs/some_pack/some_class_with_new_name.rb
            YML
          ]
        end

        let(:some_pack_package_todo_before) do
          write_file('packs/some_pack/package_todo.yml', <<~YML.strip)
            ---
            packs/some_other_pack:
              "OtherPackClass":
                violations:
                - privacy
                files:
                - packs/some_pack/some_class_with_old_name.rb
          YML
        end

        it 'does not display a markdown message' do
          subject
          expect(dangerfile).to produce_no_danger_messages
        end
      end

      context 'a package_todo.yml file has been modified with files that have been renamed AND been added' do
        let(:renamed_files) do
          [
            {
              after: 'packs/some_pack/some_class_with_new_name.rb',
              before: 'packs/some_pack/some_class_with_old_name.rb'
            }
          ]
        end

        let(:added_files) { ['packs/some_pack/some_entirely_new_class.rb'] }

        let(:modified_files) do
          [
            write_file('packs/some_pack/package_todo.yml', <<~YML.strip)
              ---
              packs/some_other_pack:
                "OtherPackClass":
                  violations:
                  - privacy
                  files:
                  - packs/some_pack/some_class_with_new_name.rb
                  - packs/some_pack/some_entirely_new_class.rb
            YML
          ]
        end

        let(:some_pack_package_todo_before) do
          write_file('packs/some_pack/package_todo.yml', <<~YML.strip)
            ---
            packs/some_other_pack:
              "OtherPackClass":
                violations:
                - privacy
                files:
                - packs/some_pack/some_class_with_old_name.rb
          YML
        end

        it 'does not display a markdown message' do
          subject
          expect('packs/some_pack/package_todo.yml').to contain_inline_markdown(
            <<~EXPECTED
              ---
              packs/some_other_pack:
                "OtherPackClass":
                  violations:
                  - privacy
                  files:
                  - packs/some_pack/some_class_with_new_name.rb
                  - packs/some_pack/some_entirely_new_class.rb
              ==================== DANGER_START
              Hi again! It looks like `OtherPackClass` is private API of `packs/some_other_pack`.
              We noticed you ran `bin/packwerk update-todo`. Check out [the docs](https://github.com/Shopify/packwerk/blob/main/RESOLVING_VIOLATIONS.md) to see other ways to resolve violations.

              - Could you add some context as a reply here about why we needed to add this violation?

              ==================== DANGER_END
            EXPECTED
          ).and_nothing_else
        end
      end

      context 'a package_todo.yml file has been modified with constants that have been renamed' do
        let(:renamed_files) do
          [
            {
              after: 'packs/some_pack/some_class_with_new_name.rb',
              before: 'packs/some_pack/some_class_with_old_name.rb'
            }
          ]
        end

        let(:modified_files) do
          [
            write_file('packs/some_pack/package_todo.yml', <<~YML.strip)
              ---
              packs/some_other_pack:
                "SomeClassWithNewName":
                  violations:
                  - privacy
                  files:
                  - packs/some_pack/some_file.rb
            YML
          ]
        end

        let(:some_pack_package_todo_before) do
          write_file('packs/some_pack/package_todo.yml', <<~YML.strip)
            ---
            packs/some_other_pack:
              "SomeClassWithOldName":
                violations:
                - privacy
                files:
                - packs/some_pack/some_file.rb
          YML
        end

        it 'does not display a markdown message' do
          subject
          expect(dangerfile).to produce_no_danger_messages
        end
      end

      context 'a package_todo.yml file has been modified with constants that have been renamed AND been added' do
        let(:renamed_files) do
          [
            {
              after: 'packs/some_pack/some_class_with_new_name.rb',
              before: 'packs/some_pack/some_class_with_old_name.rb'
            }
          ]
        end

        let(:added_files) { ['packs/some_pack/some_entirely_new_class.rb'] }

        let(:modified_files) do
          [
            write_file('packs/some_pack/package_todo.yml', <<~YML.strip)
              ---
              packs/some_other_pack:
                "SomeClassWithNewName":
                  violations:
                  - privacy
                  files:
                  - packs/some_pack/some_file.rb
                "SomeNewClass":
                  violations:
                  - privacy
                  files:
                  - packs/some_pack/some_file.rb
            YML
          ]
        end

        let(:some_pack_package_todo_before) do
          write_file('packs/some_pack/package_todo.yml', <<~YML.strip)
            ---
            packs/some_other_pack:
              "SomeClassWithOldName":
                violations:
                - privacy
                files:
                - packs/some_pack/some_file.rb
          YML
        end

        it 'does display a markdown message' do
          subject
          expect('packs/some_pack/package_todo.yml').to contain_inline_markdown(
            <<~EXPECTED
              ---
              packs/some_other_pack:
                "SomeClassWithNewName":
                  violations:
                  - privacy
                  files:
                  - packs/some_pack/some_file.rb
                "SomeNewClass":
                  violations:
                  - privacy
                  files:
                  - packs/some_pack/some_file.rb
              ==================== DANGER_START
              Hi again! It looks like `SomeNewClass` is private API of `packs/some_other_pack`.
              We noticed you ran `bin/packwerk update-todo`. Check out [the docs](https://github.com/Shopify/packwerk/blob/main/RESOLVING_VIOLATIONS.md) to see other ways to resolve violations.

              - Could you add some context as a reply here about why we needed to add this violation?

              ==================== DANGER_END
            EXPECTED
          ).and_nothing_else
        end
      end

      context 'a package has been renamed, causing a package_todo.yml file to be deleted but registered as a modification' do
        before do
          write_file('packs/some_pack/package_todo.yml', <<~YML.strip)
            ---
            packs/some_other_pack:
              "SomeClassWithNewName":
                violations:
                - privacy
                files:
                - packs/some_pack/some_file.rb
          YML
        end

        let(:renamed_files) do
          [
            {
              after: 'packs/some_pack/package_todo.yml',
              before: 'packs/old_pack_name/package_todo.yml'
            }
          ]
        end

        let(:modified_files) do
          [
            some_pack_package_todo_before
          ]
        end

        let(:some_pack_package_todo_before) do
          'packs/old_pack_name/package_todo.yml'
        end

        it 'does not display a markdown message' do
          subject
          expect(dangerfile).to produce_no_danger_messages
        end
      end

      context 'an unknown violation type is added to a new package_todo.yml file' do
        let(:added_files) { ['packs/some_pack/package_todo.yml'] }

        before do
          write_file('packs/some_pack/package_todo.yml', <<~YML.strip)
            ---
            packs/some_other_pack:
              "OtherPackClass":
                violations:
                - unknown
                files:
                - packs/some_pack/some_class.rb
          YML
        end

        it 'calls the before comment input proc' do
          expect(slack_notifier).to receive(:notify_slack).with(
            { dependency: { minus: 0, plus: 0 }, privacy: { minus: 0, plus: 0 } },
            ['packs/some_pack/package_todo.yml']
          )

          subject
        end

        context 'a offenses formatter is passed in' do
          let(:offenses_formatter) do
            Class.new do
              include Update::OffensesFormatter

              def format_offenses(added_violations, repo_link, org_name)
                <<~MESSAGE
                  There are #{added_violations.count} new violations,
                  with class_names #{added_violations.map(&:class_name).uniq.sort},
                  with to_package_names #{added_violations.map(&:to_package_name).uniq.sort},
                  with types #{added_violations.map(&:type).sort},
                MESSAGE
              end
            end
          end

          subject do
            danger_package_todo_yml_changes.check(
              offenses_formatter: offenses_formatter.new,
              before_comment: lambda do |_violation_diff, changed_package_todo_ymls|
                slack_notifier.notify_slack(changed_package_todo_ymls)
              end
            )
          end

          it 'displays no markdowns' do
            subject
            expect(dangerfile.status_report[:markdowns]).to be_empty
          end

          context 'user has specified to receive comments about these unknown violations' do
            subject do
              danger_package_todo_yml_changes.check(
                violation_types: ['unknown'],
                offenses_formatter: offenses_formatter.new,
                before_comment: lambda do |_violation_diff, changed_package_todo_ymls|
                  slack_notifier.notify_slack(changed_package_todo_ymls)
                end
              )
            end

            it 'displays a markdown using the passed in offenses formatter' do
              subject

              expect('packs/some_pack/package_todo.yml').to contain_inline_markdown(
                <<~EXPECTED
                  ---
                  packs/some_other_pack:
                    "OtherPackClass":
                      violations:
                      - unknown
                      files:
                      - packs/some_pack/some_class.rb
                  ==================== DANGER_START
                  There are 1 new violations,
                  with class_names ["OtherPackClass"],
                  with to_package_names ["packs/some_other_pack"],
                  with types ["unknown"],
                  ==================== DANGER_END
                EXPECTED
              ).and_nothing_else
            end
          end
        end
      end
    end
  end
end
