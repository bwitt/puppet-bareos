# frozen_string_literal: true

require 'spec_helper_acceptance'

describe 'bareos' do
  # The catalog database is set up with puppetlabs/postgresql, which isn't a module dependency
  before(:all) { install_puppet_module_via_pmt_on(hosts, 'puppetlabs-postgresql') }

  it_behaves_like 'an idempotent resource' do
    let(:manifest) do
      <<~PUPPET
        include postgresql::server

        class { 'bareos::profile::director':
          password         => 'DirectorPassword',
          catalog_conf     => {
            'db_name'     => 'bareos_catalog',
            'db_user'     => 'bareos',
            'db_password' => 'CatalogPassword',
          },
          storage_password => 'StoragePassword',
        }
        Class['postgresql::server'] -> Class['bareos::profile::director']

        class { 'bareos::profile::storage':
          password => 'StoragePassword',
        }
      PUPPET
    end
  end

  describe file('/etc/bareos/bareos-dir.d/catalog/MyCatalog.conf') do
    its(:content) { is_expected.to match %r{Db Name = "bareos_catalog"} }
  end

  describe file('/etc/bareos/bareos-fd.d/client/bareos-fd.conf') do
    its(:content) { is_expected.to match %r{Name = "bareos-director-fd"} }
  end

  describe file('/etc/bareos/bareos-sd.d/device/FileStorage.conf') do
    its(:content) { is_expected.to match %r{Archive Device = "/var/lib/bareos/storage"} }
  end

  {
    'bareos-director' => ['bareos-dir', 9101],
    'bareos-filedaemon' => ['bareos-fd', 9102],
    'bareos-storage' => ['bareos-sd', 9103],
  }.each do |pkg, (svc, port)|
    describe package(pkg) do
      it { is_expected.to be_installed }
    end

    describe service(svc) do
      it { is_expected.to be_enabled }
      it { is_expected.to be_running }
    end

    # As the bareos user, which the catalog connection authenticates as
    describe command("su -s /bin/sh bareos -c '#{svc} -t'") do
      its(:exit_status) { is_expected.to eq 0 }
    end

    describe port(port) do
      it { is_expected.to be_listening }
    end
  end

  describe command('echo "status director" | bconsole') do
    its(:exit_status) { is_expected.to eq 0 }
    its(:stdout) { is_expected.to match %r{bareos-dir Version} }
  end

  describe command("su - postgres -c \"psql -d bareos_catalog -tAc 'SELECT versionid FROM version'\"") do
    its(:stdout) { is_expected.to match %r{^[0-9]+$} }
  end
end
