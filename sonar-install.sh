#!/bin/sh

apk add --no-cache openjdk17 procps

# Install PostgreSQL
apk add --no-cache postgresql postgresql-client openrc
rc-update add postgresql


# Starting the server

su - postgres -c 'mkdir /var/lib/postgresql/data'
su - postgres -c 'chown postgres:postgres /var/lib/postgresql/data'
su - postgres -c 'initdb -D /var/lib/postgresql/data'
su - postgres -c 'echo "LANG=en_US.utf8" > /var/lib/postgresql/data/environment'

sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" /var/lib/postgresql/data/postgresql.conf
echo "host all all 0.0.0.0/0 md5" >> /var/lib/postgresql/data/pg_hba.conf
touch /var/log/postgresql.log
chown postgres:postgres /var/log/postgresql.log

mkdir /run/postgresql
chown postgres:postgres /run/postgresql

rc-service postgresql start
su - postgres -c 'pg_ctl -D /var/lib/postgresql/data -l /var/log/postgresql.log start'
su - postgres -c 'psql -c "SELECT version();"'

# Create a new database and user in PostgreSQL for SonarQube
su - postgres psql -c "createdb sonarqube;"

su - postgres -c "psql -c \"CREATE USER sonar WITH ENCRYPTED PASSWORD 'your_password';\""
su - postgres -c "psql -c \"GRANT ALL PRIVILEGES ON DATABASE sonarqube TO sonar;\""


# Download and Install SonarQube
wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-10.0.0.68432.zip
unzip sonarqube-10.0.0.68432.zip
rm sonarqube-10.0.0.68432.zip
mv sonarqube-10.0.0.68432 /opt/sonarqube

# Configure SonarQube to use PostgreSQL
cp /opt/sonarqube/conf/sonar.properties /opt/sonarqube/conf/sonar.properties.bak
sed -i 's|#sonar.jdbc.url=jdbc:postgresql://localhost/sonarqube?currentSchema=my_schema|sonar.jdbc.url=jdbc:postgresql://localhost:5432/sonarqube|' /opt/sonarqube/conf/sonar.properties
sed -i 's|#sonar.jdbc.username=|sonar.jdbc.username=sonar|' /opt/sonarqube/conf/sonar.properties
sed -i 's|#sonar.jdbc.password=|sonar.jdbc.password=your_password|' /opt/sonarqube/conf/sonar.properties

addgroup sonar
adduser -h /opt/sonarqube -G sonar -D sonar
chown sonar:sonar /opt/sonarqube -R
su - sonar -c '/opt/sonarqube/bin/linux-x86-64/sonar.sh console'
