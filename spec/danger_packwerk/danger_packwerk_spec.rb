require 'spec_helper'

module DangerPackwerk
  RSpec.describe DangerPackwerk do
    describe '#check' do
      let(:load_paths) do
        {
          'packs/some_pack' => 'Object'
        }
      end
      let(:root_path) { nil }

      before do
        # These paths need to exist for ConstantResolver
        [
          'packs/some_pack/some_class.rb',
          'packs/some_pack/some_other_class.rb',
          'packs/some_pack/some_file.rb',
          'packs/some_pack/some_class_with_new_name.rb',
          'packs/some_pack/some_class_with_old_name.rb'
        ].each { |path| write_file(path) }
        allow(Packwerk::RailsLoadPaths).to receive(:for).and_return(load_paths)
        write_package_yml('packs/some_pack')
      end

      context 'using inputted formatter' do
        let(:packwerk) { dangerfile.packwerk }
        let(:plugin) { packwerk }
        let(:formatter) do
          Class.new do
            include Check::OffensesFormatter

            def format_offenses(offenses, repo_link, org_name)
              offenses.map(&:message).join("\n\n")
            end
          end
        end
        let(:packwerk_check) do
          packwerk.check(
            offenses_formatter: formatter.new,
            root_path: root_path
          )
        end
        let(:offenses) { [] }
        let(:files_for_packwerk) { ['packs/referencing_pack/some_file.rb'] }
        let(:modified_files) { [write_file('packs/referencing_pack/some_file.rb').to_s] }

        before do
          write_file('package.yml', <<~YML)
            enforce_dependencies: true
            enforce_privacy: true
          YML
          allow_any_instance_of(Packwerk::Cli).to receive(:execute_command).with(['check', *files_for_packwerk])
          allow_any_instance_of(PackwerkWrapper::OffensesAggregatorFormatter).to receive(:aggregated_offenses).and_return(offenses)
        end

        let(:constant) do
          sorbet_double(Packwerk::ConstantContext, location: Packwerk::Node::Location.new(12, 5), package: double(name: 'packs/some_pack'), name: '::PrivateConstant')
        end

        let(:generic_dependency_violation) do
          sorbet_double(
            Packwerk::ReferenceOffense,
            reference: reference,
            violation_type: ::DangerPackwerk::DEPENDENCY_VIOLATION_TYPE,
            message: 'Vanilla message about dependency violations',
            location: Packwerk::Node::Location.new(12, 5)
          )
        end

        let(:generic_privacy_violation) do
          sorbet_double(
            Packwerk::ReferenceOffense,
            reference: reference,
            violation_type: ::DangerPackwerk::PRIVACY_VIOLATION_TYPE,
            message: 'Vanilla message about privacy violations',
            location: Packwerk::Node::Location.new(12, 5)
          )
        end

        let(:reference) do
          sorbet_double(
            Packwerk::Reference,
            relative_path: 'packs/referencing_pack/some_file.rb',
            constant: constant
          )
        end

        context 'when there are syntax errors in analyzed files' do
          let(:offenses) { [sorbet_double(Packwerk::Parsers::ParseResult)] }

          it 'exits gracefully' do
            packwerk_check
            expect(dangerfile.status_report[:warnings]).to be_empty
            expect(dangerfile.status_report[:errors]).to be_empty
            actual_markdowns = dangerfile.status_report[:markdowns]
            expect(actual_markdowns.count).to eq 0
          end
        end

        context 'when the only files modified are ones that packwerk ignores' do
          let(:modified_files) { [write_file('frontend/javascript/some_file.js').to_s] }

          it 'leaves an inline comment helping the user figure out what to do next' do
            expect_any_instance_of(Packwerk::Cli).to_not receive(:execute_command)
            packwerk_check
            expect(dangerfile.status_report[:warnings]).to be_empty
            expect(dangerfile.status_report[:errors]).to be_empty
            actual_markdowns = dangerfile.status_report[:markdowns]
            expect(actual_markdowns.count).to eq 0
          end
        end

        context 'when there is a new privacy violation when running packwerk check' do
          let(:offenses) { [generic_privacy_violation] }

          it 'leaves an inline comment helping the user figure out what to do next' do
            packwerk_check
            expect(dangerfile.status_report[:warnings]).to be_empty
            expect(dangerfile.status_report[:errors]).to be_empty
            actual_markdowns = dangerfile.status_report[:markdowns]
            expect(actual_markdowns.count).to eq 1
            actual_markdown = actual_markdowns.first
            expect(actual_markdown.message).to eq 'Vanilla message about privacy violations'
            expect(actual_markdown.line).to eq 12
            expect(actual_markdown.file).to eq 'packs/referencing_pack/some_file.rb'
            expect(actual_markdown.type).to eq :markdown
          end

          context 'when the failure is in a renamed file' do
            let(:renamed_file) { write_file('packs/referencing_pack/some_file.rb') }
            let(:modified_file) { 'packs/referencing_pack/some_file_with_old_name.rb' }
            let(:modified_files) { [modified_file] }
            let(:renamed_files) { [{ before: modified_file, after: renamed_file.to_s }] }

            it 'leaves an inline comment helping the user figure out what to do next' do
              packwerk_check
              expect(dangerfile.status_report[:warnings]).to be_empty
              expect(dangerfile.status_report[:errors]).to be_empty
              actual_markdowns = dangerfile.status_report[:markdowns]
              expect(actual_markdowns.count).to eq 1
              actual_markdown = actual_markdowns.first
              expect(actual_markdown.message).to eq 'Vanilla message about privacy violations'
              expect(actual_markdown.line).to eq 12
              expect(actual_markdown.file).to eq 'packs/referencing_pack/some_file.rb'
              expect(actual_markdown.type).to eq :markdown
            end
          end
        end

        context 'when there is a new dependency violation when running packwerk check' do
          let(:offenses) { [generic_dependency_violation] }

          it 'leaves an inline comment helping the user figure out what to do next' do
            packwerk_check
            expect(dangerfile.status_report[:warnings]).to be_empty
            expect(dangerfile.status_report[:errors]).to be_empty
            actual_markdowns = dangerfile.status_report[:markdowns]
            expect(actual_markdowns.count).to eq 1
            actual_markdown = actual_markdowns.first
            expect(actual_markdown.message).to eq 'Vanilla message about dependency violations'
            expect(actual_markdown.line).to eq 12
            expect(actual_markdown.file).to eq 'packs/referencing_pack/some_file.rb'
            expect(actual_markdown.type).to eq :markdown
          end
        end

        context 'when there is a new dependency and privacy violation when running packwerk check' do
          let(:offenses) { [generic_dependency_violation, generic_privacy_violation] }

          it 'leaves an inline comment helping the user figure out what to do next' do
            packwerk_check
            expect(dangerfile.status_report[:warnings]).to be_empty
            expect(dangerfile.status_report[:errors]).to be_empty
            actual_markdowns = dangerfile.status_report[:markdowns]
            expect(actual_markdowns.count).to eq 1
            actual_markdown = actual_markdowns.first
            expect(actual_markdown.message).to eq "Vanilla message about dependency violations\n\nVanilla message about privacy violations"
            expect(actual_markdown.line).to eq 12
            expect(actual_markdown.file).to eq 'packs/referencing_pack/some_file.rb'
            expect(actual_markdown.type).to eq :markdown
          end
        end

        context 'when app is in a subfolder in git repo' do
          let(:root_path) { 'parent_folder/' }
          let(:modified_files) { ["#{root_path}packs/referencing_pack/some_file.rb"] }
          let(:offenses) { [generic_dependency_violation, generic_privacy_violation] }

          before { write_file('packs/referencing_pack/some_file.rb') }

          it 'leaves an inline comment helping the user figure out what to do next' do
            packwerk_check

            expect(dangerfile.status_report[:warnings]).to be_empty
            expect(dangerfile.status_report[:errors]).to be_empty
            actual_markdowns = dangerfile.status_report[:markdowns]
            expect(actual_markdowns.count).to eq 1
            actual_markdown = actual_markdowns.first
            expect(actual_markdown.message).to eq "Vanilla message about dependency violations\n\nVanilla message about privacy violations"
            expect(actual_markdown.line).to eq 12
            expect(actual_markdown.file).to eq "#{root_path}packs/referencing_pack/some_file.rb"
            expect(actual_markdown.type).to eq :markdown
          end

          context 'when the failure is in a renamed file' do
            before { write_file('packs/referencing_pack/some_file.rb') }

            let(:renamed_file) { "#{root_path}packs/referencing_pack/some_file.rb" }
            let(:modified_file) { "#{root_path}packs/referencing_pack/some_file_with_old_name.rb" }

            let(:modified_files) { [modified_file] }
            let(:renamed_files) { [{ before: modified_file, after: renamed_file.to_s }] }

            let(:offenses) { [generic_privacy_violation] }

            it 'leaves an inline comment helping the user figure out what to do next' do
              packwerk_check
              expect(dangerfile.status_report[:warnings]).to be_empty
              expect(dangerfile.status_report[:errors]).to be_empty
              actual_markdowns = dangerfile.status_report[:markdowns]
              expect(actual_markdowns.count).to eq 1
              actual_markdown = actual_markdowns.first
              expect(actual_markdown.message).to eq 'Vanilla message about privacy violations'
              expect(actual_markdown.line).to eq 12
              expect(actual_markdown.file).to eq "#{root_path}packs/referencing_pack/some_file.rb"
              expect(actual_markdown.type).to eq :markdown
            end
          end
        end

        context 'when there are violations on the same constant' do
          context 'with default (per constant per line)' do
            context 'on the same line' do
              let(:reference) do
                sorbet_double(
                  Packwerk::Reference,
                  relative_path: 'packs/referencing_pack/some_file.rb',
                  constant: constant
                )
              end

              let(:offenses) do
                [
                  sorbet_double(
                    Packwerk::ReferenceOffense,
                    reference: reference,
                    violation_type: ::DangerPackwerk::PRIVACY_VIOLATION_TYPE,
                    message: 'Vanilla message about privacy violations',
                    location: Packwerk::Node::Location.new(12, 15)
                  ),
                  sorbet_double(
                    Packwerk::ReferenceOffense,
                    reference: reference,
                    violation_type: ::DangerPackwerk::DEPENDENCY_VIOLATION_TYPE,
                    message: 'Vanilla message about dependency violations',
                    location: Packwerk::Node::Location.new(12, 15)
                  )
                ]
              end

              it 'leaves one comment' do
                packwerk_check
                expect(dangerfile.status_report[:warnings]).to be_empty
                expect(dangerfile.status_report[:errors]).to be_empty
                actual_markdowns = dangerfile.status_report[:markdowns]
                expect(actual_markdowns.count).to eq 1
                actual_markdown = actual_markdowns.first
                expect(actual_markdown.message).to eq "Vanilla message about privacy violations\n\nVanilla message about dependency violations"
                expect(actual_markdown.line).to eq 12
                expect(actual_markdown.file).to eq 'packs/referencing_pack/some_file.rb'
                expect(actual_markdown.type).to eq :markdown
              end
            end

            context 'within the same file' do
              let(:reference) do
                sorbet_double(
                  Packwerk::Reference,
                  relative_path: 'packs/referencing_pack/some_file.rb',
                  constant: constant
                )
              end

              let(:offenses) do
                [
                  sorbet_double(
                    Packwerk::ReferenceOffense,
                    reference: reference,
                    violation_type: ::DangerPackwerk::PRIVACY_VIOLATION_TYPE,
                    message: 'Vanilla message about privacy violations',
                    location: Packwerk::Node::Location.new(12, 5)
                  ),
                  sorbet_double(
                    Packwerk::ReferenceOffense,
                    reference: reference,
                    violation_type: ::DangerPackwerk::PRIVACY_VIOLATION_TYPE,
                    message: 'Vanilla message about privacy violations',
                    location: Packwerk::Node::Location.new(22, 5)
                  )
                ]
              end

              it 'leaves a comment for each violation' do
                packwerk_check
                expect(dangerfile.status_report[:warnings]).to be_empty
                expect(dangerfile.status_report[:errors]).to be_empty

                actual_markdowns = dangerfile.status_report[:markdowns]
                expect(actual_markdowns.count).to eq 2

                first_actual_markdown = actual_markdowns.first
                expect(first_actual_markdown.message).to eq 'Vanilla message about privacy violations'
                expect(first_actual_markdown.line).to eq 12
                expect(first_actual_markdown.file).to eq 'packs/referencing_pack/some_file.rb'
                expect(first_actual_markdown.type).to eq :markdown

                second_actual_markdown = actual_markdowns.last
                expect(second_actual_markdown.message).to eq 'Vanilla message about privacy violations'
                expect(second_actual_markdown.line).to eq 22
                expect(second_actual_markdown.file).to eq 'packs/referencing_pack/some_file.rb'
                expect(second_actual_markdown.type).to eq :markdown
              end
            end

            context 'within the same pack' do
              let(:offenses) do
                [
                  sorbet_double(
                    Packwerk::ReferenceOffense,
                    reference: sorbet_double(
                      Packwerk::Reference,
                      relative_path: 'packs/referencing_pack/some_file.rb',
                      constant: constant
                    ),
                    violation_type: ::DangerPackwerk::PRIVACY_VIOLATION_TYPE,
                    message: 'Vanilla message about privacy violations',
                    location: Packwerk::Node::Location.new(12, 5)
                  ),
                  sorbet_double(
                    Packwerk::ReferenceOffense,
                    reference: sorbet_double(
                      Packwerk::Reference,
                      relative_path: 'packs/referencing_pack/some_other_file.rb',
                      constant: constant
                    ),
                    violation_type: ::DangerPackwerk::PRIVACY_VIOLATION_TYPE,
                    message: 'Vanilla message about privacy violations',
                    location: Packwerk::Node::Location.new(12, 5)
                  )
                ]
              end

              it 'leaves a comment for each violation' do
                packwerk_check
                expect(dangerfile.status_report[:warnings]).to be_empty
                expect(dangerfile.status_report[:errors]).to be_empty

                actual_markdowns = dangerfile.status_report[:markdowns]
                expect(actual_markdowns.count).to eq 2

                first_actual_markdown = actual_markdowns.first
                expect(first_actual_markdown.message).to eq 'Vanilla message about privacy violations'
                expect(first_actual_markdown.line).to eq 12
                expect(first_actual_markdown.file).to eq 'packs/referencing_pack/some_file.rb'
                expect(first_actual_markdown.type).to eq :markdown

                second_actual_markdown = actual_markdowns.last
                expect(second_actual_markdown.message).to eq 'Vanilla message about privacy violations'
                expect(second_actual_markdown.line).to eq 12
                expect(second_actual_markdown.file).to eq 'packs/referencing_pack/some_other_file.rb'
                expect(second_actual_markdown.type).to eq :markdown
              end
            end

            context 'across different packs' do
              let(:offenses) do
                [
                  sorbet_double(
                    Packwerk::ReferenceOffense,
                    reference: sorbet_double(
                      Packwerk::Reference,
                      relative_path: 'packs/referencing_pack/some_file.rb',
                      constant: constant
                    ),
                    violation_type: ::DangerPackwerk::PRIVACY_VIOLATION_TYPE,
                    message: 'Vanilla message about privacy violations',
                    location: Packwerk::Node::Location.new(12, 5)
                  ),
                  sorbet_double(
                    Packwerk::ReferenceOffense,
                    reference: sorbet_double(
                      Packwerk::Reference,
                      relative_path: 'packs/another_referencing_pack/some_file.rb',
                      constant: constant
                    ),
                    violation_type: ::DangerPackwerk::PRIVACY_VIOLATION_TYPE,
                    message: 'Vanilla message about privacy violations',
                    location: Packwerk::Node::Location.new(12, 5)
                  )
                ]
              end

              it 'leaves a comment for each violation' do
                packwerk_check
                expect(dangerfile.status_report[:warnings]).to be_empty
                expect(dangerfile.status_report[:errors]).to be_empty

                actual_markdowns = dangerfile.status_report[:markdowns]
                expect(actual_markdowns.count).to eq 2

                first_actual_markdown = actual_markdowns.first
                expect(first_actual_markdown.message).to eq 'Vanilla message about privacy violations'
                expect(first_actual_markdown.line).to eq 12
                expect(first_actual_markdown.file).to eq 'packs/referencing_pack/some_file.rb'
                expect(first_actual_markdown.type).to eq :markdown

                second_actual_markdown = actual_markdowns.last
                expect(second_actual_markdown.message).to eq 'Vanilla message about privacy violations'
                expect(second_actual_markdown.line).to eq 12
                expect(second_actual_markdown.file).to eq 'packs/another_referencing_pack/some_file.rb'
                expect(second_actual_markdown.type).to eq :markdown
              end
            end
          end

          context 'with grouping per constant per pack' do
            let(:packwerk_check) do
              packwerk.check(
                offenses_formatter: formatter.new,
                grouping_strategy: DangerPackwerk::PerConstantPerPackGrouping
              )
            end

            context 'on the same line' do
              let(:reference) do
                sorbet_double(
                  Packwerk::Reference,
                  relative_path: 'packs/referencing_pack/some_file.rb',
                  constant: constant
                )
              end

              let(:offenses) do
                [
                  sorbet_double(
                    Packwerk::ReferenceOffense,
                    reference: reference,
                    violation_type: ::DangerPackwerk::PRIVACY_VIOLATION_TYPE,
                    message: 'Vanilla message about privacy violations',
                    location: Packwerk::Node::Location.new(12, 15)
                  ),
                  sorbet_double(
                    Packwerk::ReferenceOffense,
                    reference: reference,
                    violation_type: ::DangerPackwerk::DEPENDENCY_VIOLATION_TYPE,
                    message: 'Vanilla message about dependency violations',
                    location: Packwerk::Node::Location.new(12, 15)
                  )
                ]
              end

              it 'leaves one comment' do
                packwerk_check
                expect(dangerfile.status_report[:warnings]).to be_empty
                expect(dangerfile.status_report[:errors]).to be_empty
                actual_markdowns = dangerfile.status_report[:markdowns]
                expect(actual_markdowns.count).to eq 1
                actual_markdown = actual_markdowns.first
                expect(actual_markdown.message).to eq "Vanilla message about privacy violations\n\nVanilla message about dependency violations"
                expect(actual_markdown.line).to eq 12
                expect(actual_markdown.file).to eq 'packs/referencing_pack/some_file.rb'
                expect(actual_markdown.type).to eq :markdown
              end
            end

            context 'within the same file' do
              let(:reference) do
                sorbet_double(
                  Packwerk::Reference,
                  relative_path: 'packs/referencing_pack/some_file.rb',
                  constant: constant
                )
              end

              let(:offenses) do
                [
                  sorbet_double(
                    Packwerk::ReferenceOffense,
                    reference: reference,
                    violation_type: ::DangerPackwerk::PRIVACY_VIOLATION_TYPE,
                    message: 'Vanilla message about privacy violations',
                    location: Packwerk::Node::Location.new(12, 5)
                  ),
                  sorbet_double(
                    Packwerk::ReferenceOffense,
                    reference: reference,
                    violation_type: ::DangerPackwerk::PRIVACY_VIOLATION_TYPE,
                    message: 'Vanilla message about privacy violations',
                    location: Packwerk::Node::Location.new(22, 5)
                  )
                ]
              end

              it 'leaves one comment' do
                packwerk_check
                expect(dangerfile.status_report[:warnings]).to be_empty
                expect(dangerfile.status_report[:errors]).to be_empty
                actual_markdowns = dangerfile.status_report[:markdowns]
                expect(actual_markdowns.count).to eq 1
                actual_markdown = actual_markdowns.first
                expect(actual_markdown.message).to eq "Vanilla message about privacy violations\n\nVanilla message about privacy violations"
                expect(actual_markdown.line).to eq 12
                expect(actual_markdown.file).to eq 'packs/referencing_pack/some_file.rb'
                expect(actual_markdown.type).to eq :markdown
              end
            end

            context 'within the same pack' do
              let(:offenses) do
                [
                  sorbet_double(
                    Packwerk::ReferenceOffense,
                    reference: sorbet_double(
                      Packwerk::Reference,
                      relative_path: 'packs/referencing_pack/some_file.rb',
                      constant: constant
                    ),
                    violation_type: ::DangerPackwerk::PRIVACY_VIOLATION_TYPE,
                    message: 'Vanilla message about privacy violations',
                    location: Packwerk::Node::Location.new(12, 5)
                  ),
                  sorbet_double(
                    Packwerk::ReferenceOffense,
                    reference: sorbet_double(
                      Packwerk::Reference,
                      relative_path: 'packs/referencing_pack/some_other_file.rb',
                      constant: constant
                    ),
                    violation_type: ::DangerPackwerk::PRIVACY_VIOLATION_TYPE,
                    message: 'Vanilla message about privacy violations',
                    location: Packwerk::Node::Location.new(12, 5)
                  )
                ]
              end

              it 'leaves one comment' do
                packwerk_check
                expect(dangerfile.status_report[:warnings]).to be_empty
                expect(dangerfile.status_report[:errors]).to be_empty
                actual_markdowns = dangerfile.status_report[:markdowns]
                expect(actual_markdowns.count).to eq 1
                actual_markdown = actual_markdowns.first
                expect(actual_markdown.message).to eq "Vanilla message about privacy violations\n\nVanilla message about privacy violations"
                expect(actual_markdown.line).to eq 12
                expect(actual_markdown.file).to eq 'packs/referencing_pack/some_file.rb'
                expect(actual_markdown.type).to eq :markdown
              end
            end

            context 'across different packs' do
              before do
                write_file('packs/referencing_pack/package.yml', <<~YML)
                  enforce_dependencies: true
                  enforce_privacy: true
                YML
                write_file('packs/another_referencing_pack/package.yml', <<~YML)
                  enforce_dependencies: true
                  enforce_privacy: true
                YML
              end

              let(:offenses) do
                [
                  sorbet_double(
                    Packwerk::ReferenceOffense,
                    reference: sorbet_double(
                      Packwerk::Reference,
                      relative_path: 'packs/referencing_pack/some_file.rb',
                      constant: constant
                    ),
                    violation_type: ::DangerPackwerk::PRIVACY_VIOLATION_TYPE,
                    message: 'Vanilla message about privacy violations',
                    location: Packwerk::Node::Location.new(12, 5)
                  ),
                  sorbet_double(
                    Packwerk::ReferenceOffense,
                    reference: sorbet_double(
                      Packwerk::Reference,
                      relative_path: 'packs/another_referencing_pack/some_file.rb',
                      constant: constant
                    ),
                    violation_type: ::DangerPackwerk::PRIVACY_VIOLATION_TYPE,
                    message: 'Vanilla message about privacy violations',
                    location: Packwerk::Node::Location.new(12, 5)
                  )
                ]
              end

              it 'leaves a comment for each violation' do
                packwerk_check
                expect(dangerfile.status_report[:warnings]).to be_empty
                expect(dangerfile.status_report[:errors]).to be_empty

                actual_markdowns = dangerfile.status_report[:markdowns]
                expect(actual_markdowns.count).to eq 2

                first_actual_markdown = actual_markdowns.first
                expect(first_actual_markdown.message).to eq 'Vanilla message about privacy violations'
                expect(first_actual_markdown.line).to eq 12
                expect(first_actual_markdown.file).to eq 'packs/referencing_pack/some_file.rb'
                expect(first_actual_markdown.type).to eq :markdown

                second_actual_markdown = actual_markdowns.last
                expect(second_actual_markdown.message).to eq 'Vanilla message about privacy violations'
                expect(second_actual_markdown.line).to eq 12
                expect(second_actual_markdown.file).to eq 'packs/another_referencing_pack/some_file.rb'
                expect(second_actual_markdown.type).to eq :markdown
              end
            end
          end
        end

        context 'when there are 100 new violations when running packwerk check' do
          let(:offenses) do
            100.times.to_a.map do |i|
              sorbet_double(
                Packwerk::ReferenceOffense,
                violation_type: ::DangerPackwerk::DEPENDENCY_VIOLATION_TYPE,
                reference: reference,
                message: 'blah',
                location: Packwerk::Node::Location.new(i, 5)
              )
            end
          end

          context 'the user has not passed in max comments' do
            it 'stops commenting after 15 comments' do
              packwerk_check
              expect(dangerfile.status_report[:warnings]).to be_empty
              expect(dangerfile.status_report[:errors]).to be_empty
              actual_markdowns = dangerfile.status_report[:markdowns]
              expect(actual_markdowns.count).to eq 15
            end
          end

          context 'the user has passed in max comments' do
            it 'stops commenting after the user configured number of comments' do
              packwerk.check(offenses_formatter: formatter.new, max_comments: 3)
              expect(dangerfile.status_report[:warnings]).to be_empty
              expect(dangerfile.status_report[:errors]).to be_empty
              actual_markdowns = dangerfile.status_report[:markdowns]
              expect(actual_markdowns.count).to eq 3
            end
          end
        end

        context 'the user has passed fail_build' do
          context 'there are offenses' do
            let(:offenses) { [generic_dependency_violation, generic_privacy_violation] }

            it 'fails the build' do
              packwerk.check(
                offenses_formatter: formatter.new,
                fail_build: true
              )
              expect(dangerfile.status_report[:warnings]).to be_empty
              expect(dangerfile.status_report[:errors]).to eq(['Packwerk violations were detected! Please resolve them to unblock the build.'])
            end
          end

          context 'the user has passed in a failure message and there are offenses' do
            let(:offenses) { [generic_dependency_violation, generic_privacy_violation] }

            it 'fails the build' do
              packwerk.check(offenses_formatter: formatter.new, fail_build: true, failure_message: 'Custom error message!')
              expect(dangerfile.status_report[:warnings]).to be_empty
              expect(dangerfile.status_report[:errors]).to eq(['Custom error message!'])
            end
          end

          context 'there are no offenses' do
            it 'does not fail the build' do
              packwerk.check(offenses_formatter: formatter.new, fail_build: true)
              expect(dangerfile.status_report[:warnings]).to be_empty
              expect(dangerfile.status_report[:errors]).to be_empty
            end
          end
        end

        context 'the user has configured on_failure' do
          let(:offenses) { [generic_dependency_violation, generic_privacy_violation] }

          it 'fails the build' do
            on_failure_called_message = false
            packwerk.check(
              offenses_formatter: formatter.new,
              on_failure: lambda { |offenses|
                on_failure_called_message = "`on_failure` called with #{offenses.count} offenses"
              }
            )
            expect(on_failure_called_message).to eq '`on_failure` called with 2 offenses'
          end
        end

        context 'when there are new violations on renamed files' do
          let(:files_for_packwerk) do
            [
              'packs/referencing_pack/some_file.rb',
              'packs/some_pack/some_class_with_new_name.rb'
            ]
          end
          let(:renamed_files) do
            [
              {
                after: 'packs/some_pack/some_class_with_new_name.rb',
                before: 'packs/some_pack/some_class_with_old_name.rb'
              }
            ]
          end

          let(:constant) do
            sorbet_double(Packwerk::ConstantContext, name: 'SomeClassWithNewName')
          end

          let(:offenses) { [generic_dependency_violation] }

          it 'does not leave an inline comment' do
            packwerk_check
            expect(dangerfile.status_report[:warnings]).to be_empty
            expect(dangerfile.status_report[:errors]).to be_empty
            expect(dangerfile.status_report[:markdowns]).to be_empty
          end
        end

        context 'when there is a new unknown violation when running packwerk check' do
          let(:unknown_violation) do
            sorbet_double(
              Packwerk::ReferenceOffense,
              reference: reference,
              violation_type: 'unknown',
              message: 'Some unknown message',
              location: Packwerk::Node::Location.new(12, 5)
            )
          end
          let(:offenses) { [unknown_violation] }

          it 'does not leave an inline comment helping the user figure out what to do next' do
            packwerk.check(offenses_formatter: formatter.new)
            expect(dangerfile.status_report[:warnings]).to be_empty
            expect(dangerfile.status_report[:errors]).to be_empty
            expect(dangerfile.status_report[:markdowns]).to be_empty
          end

          context 'user has specified to receive comments about these unknown violations' do
            it 'does leave an inline comment helping the user figure out what to do next' do
              packwerk.check(violation_types: ['unknown'], offenses_formatter: formatter.new)
              expect(dangerfile.status_report[:warnings]).to be_empty
              expect(dangerfile.status_report[:errors]).to be_empty
              actual_markdowns = dangerfile.status_report[:markdowns]
              expect(actual_markdowns.count).to eq 1
              actual_markdown = actual_markdowns.first
              expect(actual_markdown.message).to eq 'Some unknown message'
              expect(actual_markdown.line).to eq 12
              expect(actual_markdown.file).to eq 'packs/referencing_pack/some_file.rb'
              expect(actual_markdown.type).to eq :markdown
            end
          end
        end
      end

      context 'using default formatter' do
        subject do
          danger_packwerk.check(
            grouping_strategy: DangerPackwerk::PerConstantPerPackGrouping,
            offenses_formatter: Check::DefaultFormatter.new(
              custom_help_message: 'Need help? Join us in #ruby-modularity or see go/packs.'
            )
          )
        end

        before do
          ParsePackwerk.bust_cache!
          write_package_yml('packs/referencing_package')
          write_package_yml('packs/gusto_slack')

          allow(CodeOwnership).to receive(:for_package) do |package|
            if package.name == 'packs/referencing_package' # rubocop:disable Style/CaseLikeIf:
              CodeTeams.find('Other Team')
            elsif package.name == 'packs/gusto_slack'
              CodeTeams.find('Product Infrastructure Backend')
            end
          end

          allow_any_instance_of(Packwerk::Cli).to receive(:execute_command)
          allow_any_instance_of(::DangerPackwerk::PackwerkWrapper::OffensesAggregatorFormatter).to receive(:aggregated_offenses).and_return(offenses)

          write_file('config/teams/product_infrastructure.yml', <<~YML)
            name: Product Infrastructure Backend
            github:
              team: '@MyOrg/product-infrastructure'
            slack:
              handle: '@prod-infra-team'
              room_for_robots: '#prod-infra'
              room_for_humans: '#prod-infra'
          YML

          write_file('config/teams/other_team.yml', <<~YML)
            name: Other Team
            github:
              team: '@MyOrg/other-team'
            slack:
              handle: '@other-team'
              room_for_robots: '#other-team'
              room_for_humans: '#other-team'
          YML
        end

        let(:danger_packwerk) { dangerfile.packwerk }
        let(:generic_privacy_violation) do
          sorbet_double(
            Packwerk::ReferenceOffense,
            violation_type: ::DangerPackwerk::PRIVACY_VIOLATION_TYPE,
            reference: reference,
            location: Packwerk::Node::Location.new(12, 5)
          )
        end
        let(:generic_dependency_violation) do
          sorbet_double(
            Packwerk::ReferenceOffense,
            violation_type: ::DangerPackwerk::DEPENDENCY_VIOLATION_TYPE,
            reference: reference,
            location: Packwerk::Node::Location.new(12, 5)
          )
        end
        let(:constant) do
          sorbet_double(Packwerk::ConstantContext, package: slack_package, name: '::PrivateConstant', location: 'packs/gusto_slack/app/services/private_constant.rb')
        end
        let(:reference) do
          sorbet_double(
            Packwerk::Reference,
            package: referencing_package,
            relative_path: 'packs/referencing_package/some_file.rb',
            constant: constant
          )
        end
        let(:referencing_package) { ParsePackwerk.find('packs/referencing_package') }
        let(:offenses) { [] }
        let(:plugin) { danger_packwerk }
        let(:slack_package) { ParsePackwerk.find('packs/gusto_slack') }

        context 'when there is a new privacy violation when running packwerk check' do
          let(:offenses) { [generic_privacy_violation] }
          let(:modified_files) { [write_file('packs/referencing_package/some_file.rb').to_s] }

          it 'leaves an inline comment helping the user figure out what to do next' do
            subject
            expect(dangerfile.status_report[:warnings]).to be_empty
            expect(dangerfile.status_report[:errors]).to be_empty
            actual_markdowns = dangerfile.status_report[:markdowns]
            expect(actual_markdowns.count).to eq 1
            actual_markdown = actual_markdowns.first
            expected = <<~EXPECTED
              **Packwerk Violation**
              - Type: Privacy :lock:
              - Constant: [<ins>`PrivateConstant`</ins>](https://github.com/MyOrg/my_repo/blob/main/packs/gusto_slack/app/services/private_constant.rb)
              - Owning pack: packs/gusto_slack
                - Owned by [<ins>@MyOrg/product-infrastructure</ins>](https://github.com/orgs/MyOrg/teams/product-infrastructure/members) (Slack: [<ins>#prod-infra</ins>](https://slack.com/app_redirect?channel=prod-infra))

              <details><summary>Quick suggestions :bulb:</summary>

              Before you run `bin/packwerk update-todo`, check out these quick suggestions:
              - Does the code you are writing live in the right pack?
                - If not, try `bin/packs move packs/destination_pack packs/referencing_package/some_file.rb`
              - Does PrivateConstant live in the right pack?
                - If not, try `bin/packs move packs/destination_pack packs/gusto_slack/app/services/private_constant.rb`
              - Does API in packs/gusto_slack/public support this use case?
                - If not, can we work with [<ins>@MyOrg/product-infrastructure</ins>](https://github.com/orgs/MyOrg/teams/product-infrastructure/members) to create and use a public API?
                - If `PrivateConstant` should already be public, try `bin/packs make_public packs/gusto_slack/app/services/private_constant.rb`.

              </details>

              _Need help? Join us in #ruby-modularity or see go/packs._
            EXPECTED

            expect(actual_markdown.message).to eq expected
            expect(actual_markdown.line).to eq 12
            expect(actual_markdown.file).to eq 'packs/referencing_package/some_file.rb'
            expect(actual_markdown.type).to eq :markdown
          end

          context 'there is no owning team' do
            before do
              allow(CodeOwnership).to receive(:for_package).and_return(nil)
            end

            it 'leaves an inline comment helping the user figure out what to do next' do
              subject
              expect(dangerfile.status_report[:warnings]).to be_empty
              expect(dangerfile.status_report[:errors]).to be_empty
              actual_markdowns = dangerfile.status_report[:markdowns]
              expect(actual_markdowns.count).to eq 1
              actual_markdown = actual_markdowns.first
              expected = <<~EXPECTED
                **Packwerk Violation**
                - Type: Privacy :lock:
                - Constant: [<ins>`PrivateConstant`</ins>](https://github.com/MyOrg/my_repo/blob/main/packs/gusto_slack/app/services/private_constant.rb)
                - Owning pack: packs/gusto_slack
                  - This pack is unowned.

                <details><summary>Quick suggestions :bulb:</summary>

                Before you run `bin/packwerk update-todo`, check out these quick suggestions:
                - Does the code you are writing live in the right pack?
                  - If not, try `bin/packs move packs/destination_pack packs/referencing_package/some_file.rb`
                - Does PrivateConstant live in the right pack?
                  - If not, try `bin/packs move packs/destination_pack packs/gusto_slack/app/services/private_constant.rb`
                - Does API in packs/gusto_slack/public support this use case?
                  - If not, can we work with the pack owner to create and use a public API?
                  - If `PrivateConstant` should already be public, try `bin/packs make_public packs/gusto_slack/app/services/private_constant.rb`.

                </details>

                _Need help? Join us in #ruby-modularity or see go/packs._
              EXPECTED

              expect(actual_markdown.message).to eq expected
              expect(actual_markdown.line).to eq 12
              expect(actual_markdown.file).to eq 'packs/referencing_package/some_file.rb'
              expect(actual_markdown.type).to eq :markdown
            end
          end
        end

        context 'when there is a new dependency violation when running packwerk check' do
          let(:offenses) { [generic_dependency_violation] }
          let(:modified_files) { [write_file('packs/referencing_package/some_file.rb').to_s] }

          it 'leaves an inline comment helping the user figure out what to do next' do
            subject
            expect(dangerfile.status_report[:warnings]).to be_empty
            expect(dangerfile.status_report[:errors]).to be_empty
            actual_markdowns = dangerfile.status_report[:markdowns]
            expect(actual_markdowns.count).to eq 1
            actual_markdown = actual_markdowns.first

            expected = <<~EXPECTED
              **Packwerk Violation**
              - Type: Dependency :knot:
              - Constant: [<ins>`PrivateConstant`</ins>](https://github.com/MyOrg/my_repo/blob/main/packs/gusto_slack/app/services/private_constant.rb)
              - Owning pack: packs/gusto_slack
                - Owned by [<ins>@MyOrg/product-infrastructure</ins>](https://github.com/orgs/MyOrg/teams/product-infrastructure/members) (Slack: [<ins>#prod-infra</ins>](https://slack.com/app_redirect?channel=prod-infra))

              <details><summary>Quick suggestions :bulb:</summary>

              Before you run `bin/packwerk update-todo`, check out these quick suggestions:
              - Does the code you are writing live in the right pack?
                - If not, try `bin/packs move packs/destination_pack packs/referencing_package/some_file.rb`
              - Does PrivateConstant live in the right pack?
                - If not, try `bin/packs move packs/destination_pack packs/gusto_slack/app/services/private_constant.rb`
              - Do we actually want to depend on packs/gusto_slack?
                - If so, try `bin/packs add_dependency packs/referencing_package packs/gusto_slack`
                - If not, what can we change about the design so we do not have to depend on packs/gusto_slack?

              </details>

              _Need help? Join us in #ruby-modularity or see go/packs._
            EXPECTED

            expect(actual_markdown.message).to eq expected
            expect(actual_markdown.line).to eq 12
            expect(actual_markdown.file).to eq 'packs/referencing_package/some_file.rb'
            expect(actual_markdown.type).to eq :markdown
          end
        end

        context 'when there is a new dependency and privacy violation when running packwerk check' do
          let(:offenses) { [generic_dependency_violation, generic_privacy_violation] }
          let(:modified_files) { [write_file('packs/referencing_package/some_file.rb').to_s] }

          it 'leaves an inline comment helping the user figure out what to do next' do
            subject
            expect(dangerfile.status_report[:warnings]).to be_empty
            expect(dangerfile.status_report[:errors]).to be_empty
            actual_markdowns = dangerfile.status_report[:markdowns]
            expect(actual_markdowns.count).to eq 1
            actual_markdown = actual_markdowns.first
            expected = <<~EXPECTED
              **Packwerk Violation**
              - Type: Privacy :lock: + Dependency :knot:
              - Constant: [<ins>`PrivateConstant`</ins>](https://github.com/MyOrg/my_repo/blob/main/packs/gusto_slack/app/services/private_constant.rb)
              - Owning pack: packs/gusto_slack
                - Owned by [<ins>@MyOrg/product-infrastructure</ins>](https://github.com/orgs/MyOrg/teams/product-infrastructure/members) (Slack: [<ins>#prod-infra</ins>](https://slack.com/app_redirect?channel=prod-infra))

              <details><summary>Quick suggestions :bulb:</summary>

              Before you run `bin/packwerk update-todo`, check out these quick suggestions:
              - Does the code you are writing live in the right pack?
                - If not, try `bin/packs move packs/destination_pack packs/referencing_package/some_file.rb`
              - Does PrivateConstant live in the right pack?
                - If not, try `bin/packs move packs/destination_pack packs/gusto_slack/app/services/private_constant.rb`
              - Do we actually want to depend on packs/gusto_slack?
                - If so, try `bin/packs add_dependency packs/referencing_package packs/gusto_slack`
                - If not, what can we change about the design so we do not have to depend on packs/gusto_slack?
              - Does API in packs/gusto_slack/public support this use case?
                - If not, can we work with [<ins>@MyOrg/product-infrastructure</ins>](https://github.com/orgs/MyOrg/teams/product-infrastructure/members) to create and use a public API?
                - If `PrivateConstant` should already be public, try `bin/packs make_public packs/gusto_slack/app/services/private_constant.rb`.

              </details>

              _Need help? Join us in #ruby-modularity or see go/packs._
            EXPECTED

            expect(actual_markdown.message).to eq expected
            expect(actual_markdown.line).to eq 12
            expect(actual_markdown.file).to eq 'packs/referencing_package/some_file.rb'
            expect(actual_markdown.type).to eq :markdown
          end
        end

        context 'when there are violations on the same constant' do
          context 'within the same pack' do
            let(:offenses) do
              [
                sorbet_double(
                  Packwerk::ReferenceOffense,
                  reference: sorbet_double(
                    Packwerk::Reference,
                    package: referencing_package,
                    relative_path: 'packs/referencing_package/some_file.rb',
                    constant: constant
                  ),
                  violation_type: ::DangerPackwerk::PRIVACY_VIOLATION_TYPE,
                  message: 'Vanilla message about privacy violations',
                  location: Packwerk::Node::Location.new(12, 5)
                ),
                sorbet_double(
                  Packwerk::ReferenceOffense,
                  reference: sorbet_double(
                    Packwerk::Reference,
                    package: referencing_package,
                    relative_path: 'packs/referencing_package/some_other_file.rb',
                    constant: constant
                  ),
                  violation_type: ::DangerPackwerk::PRIVACY_VIOLATION_TYPE,
                  message: 'Vanilla message about privacy violations',
                  location: Packwerk::Node::Location.new(12, 5)
                )
              ]
            end

            let(:modified_files) { [write_file('packs/referencing_package/some_file.rb').to_s] }

            it 'leaves one comment' do
              subject
              expect(dangerfile.status_report[:warnings]).to be_empty
              expect(dangerfile.status_report[:errors]).to be_empty
              actual_markdowns = dangerfile.status_report[:markdowns]
              expect(actual_markdowns.count).to eq 1
              actual_markdown = actual_markdowns.first
              expected = <<~EXPECTED
                **Packwerk Violation**
                - Type: Privacy :lock:
                - Constant: [<ins>`PrivateConstant`</ins>](https://github.com/MyOrg/my_repo/blob/main/packs/gusto_slack/app/services/private_constant.rb)
                - Owning pack: packs/gusto_slack
                  - Owned by [<ins>@MyOrg/product-infrastructure</ins>](https://github.com/orgs/MyOrg/teams/product-infrastructure/members) (Slack: [<ins>#prod-infra</ins>](https://slack.com/app_redirect?channel=prod-infra))

                <details><summary>Quick suggestions :bulb:</summary>

                Before you run `bin/packwerk update-todo`, check out these quick suggestions:
                - Does the code you are writing live in the right pack?
                  - If not, try `bin/packs move packs/destination_pack packs/referencing_package/some_file.rb`
                - Does PrivateConstant live in the right pack?
                  - If not, try `bin/packs move packs/destination_pack packs/gusto_slack/app/services/private_constant.rb`
                - Does API in packs/gusto_slack/public support this use case?
                  - If not, can we work with [<ins>@MyOrg/product-infrastructure</ins>](https://github.com/orgs/MyOrg/teams/product-infrastructure/members) to create and use a public API?
                  - If `PrivateConstant` should already be public, try `bin/packs make_public packs/gusto_slack/app/services/private_constant.rb`.

                </details>

                _Need help? Join us in #ruby-modularity or see go/packs._
              EXPECTED

              expect(actual_markdown.message).to eq expected
              expect(actual_markdown.line).to eq 12
              expect(actual_markdown.file).to eq 'packs/referencing_package/some_file.rb'
              expect(actual_markdown.type).to eq :markdown
            end
          end
        end

        context 'when there are 100 new violations when running packwerk check' do
          let(:offenses) do
            100.times.to_a.map do |i|
              sorbet_double(
                Packwerk::ReferenceOffense,
                violation_type: ::DangerPackwerk::DEPENDENCY_VIOLATION_TYPE,
                reference: sorbet_double(
                  Packwerk::Reference,
                  package: referencing_package,
                  relative_path: 'packs/referencing_package/some_file.rb',
                  constant: sorbet_double(
                    Packwerk::ConstantContext,
                    package: slack_package,
                    name: "::PrivateConstant#{i}",
                    location: 'packs/gusto_slack/app/services/private_constant.rb'
                  )
                ),
                location: Packwerk::Node::Location.new(i, 5)
              )
            end
          end

          let(:modified_files) { [write_file('packs/referencing_package/some_file.rb').to_s] }

          it 'stops commenting after 15 comments' do
            subject
            expect(dangerfile.status_report[:warnings]).to be_empty
            expect(dangerfile.status_report[:errors]).to be_empty
            actual_markdowns = dangerfile.status_report[:markdowns]
            expect(actual_markdowns.count).to eq 15
          end
        end
      end
    end
  end
end
