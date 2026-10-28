# frozen_string_literal: true

require 'spec_helper_acceptance'

# The director needs a PostgreSQL catalog, so only the file and storage daemons are tested here
describe 'bareos' do
  it_behaves_like 'an idempotent resource' do
    let(:manifest) do
      <<~PUPPET
        # Work around module bugs: the packages are not ordered after the repository, the purge
        # of /etc/bareos removes files the packages create, on Debian the ASCII-armored
        # Release.key is saved as a .gpg keyring (which apt rejects), and the default python
        # plugin package names are virtual packages there (which apt never reports as installed).
        Package <| tag == 'bareos' |> -> File['/etc/bareos']
        if $facts['os']['family'] == 'Debian' {
          class { 'bareos':
            client_package_name  => ['bareos-filedaemon', 'bareos-filedaemon-python3-plugin'],
            storage_package_name => ['bareos-storage', 'bareos-storage-python3-plugin', 'bareos-tools'],
          }
          Class['apt::update'] -> Package <| tag == 'bareos' |>
          Apt::Keyring <| title == 'bareos-keyring.gpg' |> { filename => 'bareos-keyring.asc' }
          Apt::Source <| title == 'bareos' |> { keyring => '/etc/apt/keyrings/bareos-keyring.asc' }
        } else {
          include bareos
        }

        class { 'bareos::profile::client':
          name_client => 'bareos-fd',
          password    => 'ClientPassword',
        }
        class { 'bareos::profile::storage':
          password => 'StoragePassword',
        }
      PUPPET
    end
  end

  describe file('/etc/bareos/bareos-fd.d/client/bareos-fd.conf') do
    its(:content) { is_expected.to match %r{Name = "bareos-fd"} }
  end

  describe file('/etc/bareos/bareos-fd.d/director/bareos-dir.conf') do
    its(:content) { is_expected.to match %r{Password = "ClientPassword"} }
  end

  describe file('/etc/bareos/bareos-sd.d/device/FileStorage.conf') do
    its(:content) { is_expected.to match %r{Archive Device = "/var/lib/bareos/storage"} }
  end

  { 'bareos-filedaemon' => ['bareos-fd', 9102], 'bareos-storage' => ['bareos-sd', 9103] }.each do |pkg, (svc, port)|
    describe package(pkg) do
      it { is_expected.to be_installed }
    end

    describe service(svc) do
      it { is_expected.to be_enabled }
      it { is_expected.to be_running }
    end

    describe command("#{svc} -t") do
      its(:exit_status) { is_expected.to eq 0 }
    end

    describe port(port) do
      it { is_expected.to be_listening }
    end
  end
end
