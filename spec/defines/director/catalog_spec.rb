# frozen_string_literal: true

require 'spec_helper'

describe 'bareos::director::catalog' do
  def filename
    '/etc/bareos/bareos-dir.d/catalog/name.conf'
  end

  let(:title) { 'name' }

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      context 'with default values for all parameters will fail' do
        it { is_expected.to compile.and_raise_error(%r{.*}) }
      end

      context 'with required values' do
        let(:params) do
          {
            'db_driver' => 'postgresql',
            'db_name' => 'catalogdb',
          }
        end

        it do
          is_expected.to compile.with_all_deps
          is_expected.to contain_class('bareos::director')
          is_expected.to contain_file(filename)
            .with_content(%r{^Catalog \{$})
            .with_content(%r{Name = "name"$})
            .with_tag(%w[bareos bareos_director])
        end

        it 'initializes the catalog database as the postgres user' do
          is_expected.to contain_exec('bareos director init catalog name')
            .with_user('postgres')
            .with_environment(['db_name=catalogdb'])
            .that_subscribes_to("File[#{filename}]")
            .that_notifies('Service[bareos-dir]')
        end

        context 'with a database user and password' do
          let(:params) { super().merge('db_user' => 'bareos', 'db_password' => 'secret') }

          it do
            is_expected.to contain_exec('bareos director init catalog name')
              .with_environment(['db_name=catalogdb', 'db_user=bareos', 'db_password=secret'])
          end
        end
      end

      context 'with all params set' do
        def res_helper
          BareosResourceHelper
            .new('Catalog')
            .param('name', 'Name', 'name')
            .param('description', 'Description', 'string')
            .param('db_address', 'Db Address', 'string')
            .param('db_driver', 'Db Driver', 'string')
            .param('db_name', 'Db Name', 'string')
            .param('db_password', 'Db Password', 'autopassword')
            .param('db_port', 'Db Port', 'pint32')
            .param('db_socket', 'Db Socket', 'string')
            .param('db_user', 'Db User', 'string')
            .param('disable_batch_insert', 'Disable Batch Insert', 'boolean')
            .param('exit_on_fatal', 'Exit On Fatal', 'boolean')
            .param('idle_timeout', 'Idle Timeout', 'pint32')
            .param('inc_connections', 'Inc Connections', 'pint32')
            .param('max_connections', 'Max Connections', 'pint32')
            .param('min_connections', 'Min Connections', 'pint32')
            .param('multiple_connections', 'Multiple Connections', 'bit')
            .param('reconnect', 'Reconnect', 'boolean')
            .param('validate_timeout', 'Validate Timeout', 'pint32')
        end

        let(:params) { res_helper.params }
        let(:content) { res_helper.content }

        it do
          is_expected.to compile.with_all_deps
          is_expected.to contain_file(filename)
            .with_content(content)
            .that_notifies('Service[bareos-dir]')
            .that_notifies('Exec[bareos director init catalog name]')
        end
      end

      context 'with ensure absent' do
        let(:params) { { 'ensure' => 'absent' } }

        it do
          is_expected.to contain_file(filename).with_ensure('absent')
          is_expected.not_to contain_exec('bareos director init catalog name')
        end
      end
    end
  end
end
