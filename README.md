# Deploying a Crash Management API with Ansible and Cloudformation and Automation Using Jenkins ECS with Jenkins Ec2 Agent and monitoring through Grafana, Promethues
### Prerequities

1. Python3 and python-venv
2.  Ansible
3. Docker
4. aws-cli

**Create a Github repository make it public clone to pc and open the project  and To Create directory structure copy and paste the following in your terminal of your project**
```bash
 mkdir -p ./cloudformation
 mkdir -p ./templates
 mkdir -p ./ansible
 mkdir -p ./ansible/roles
 cd ./ansible/roles
 ansible-galaxy init grafana
 ansible-galaxy init prometheus
 ansible-galaxy init crashapi 
```

#### Setup the infrastructure 
**Create an Elastic IP**
1. **Step 1**: Log in to the AWS Management Console
  - Open your web browser and go to AWS Management Console.
  - Enter your AWS credentials to log in.
2. **Step 2**: Navigate to the EC2 Dashboard
  - Once logged in, find the Services menu at the top of the page and click on it.
  - In the search bar, type EC2 and select EC2 under Compute from the dropdown list.
  - You will be directed to the EC2 Dashboard.
3. **Step 3**: Allocate a New Elastic IP
  - In the EC2 Dashboard, look for the Network & Security section in the left-hand sidebar.
  - Click on Elastic IPs.
  - You will see a page that lists all your current Elastic IPs (if any). Click on the **Allocate -Elastic IP** address button at the top-right corner of the page.
4. **Step 4**: Leave everything to default click on **Allocate**.
5. **Step 5**: Click the ip you have just created copy the ip address and allocation id the allocation starts with `eipalloc-XXXXXXXXXXXX`

#### Repeat the process for promethues and crash api server to create elastic ip

- create a `cloudformation` folder in your root directory of your project  `mkdir cloudformation` inside cloudformation folder.
- To create a `main.yaml` inside the cloudformation `touch ./cloudformation/main.yaml`
- Inside the main.yaml paste the following
```yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: AWS EC2 Backup Policy for Production Environment

```

- To create the security group and open the required port for grafana promethues and application paste the following in `main.yaml` don't forget to replace the vpc id in `VpcId`
```yaml
  GrafanaSecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupDescription: Allow HTTP to Grafana host
      # replace the vpc id
      VpcId: vpc-08a64dd4d4688a77d
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 3000
          ToPort: 3000
          CidrIp: 0.0.0.0/0
        - IpProtocol: tcp
          FromPort: 22
          ToPort: 22
          CidrIp: 0.0.0.0/0
        - IpProtocol: tcp
          FromPort: 80
          ToPort: 80
          CidrIp: 0.0.0.0/0
      SecurityGroupEgress:
        - IpProtocol: "-1"
          CidrIp: 0.0.0.0/0
        - IpProtocol: tcp
          FromPort: 443
          ToPort: 443
          CidrIp: 0.0.0.0/0

  PrometheusSecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupDescription: Allow HTTP to Prometheus host
      # replace the vpc id
      VpcId: vpc-08a64dd4d4688a77d
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 9090
          ToPort: 9090
          SourceSecurityGroupId: !Ref GrafanaSecurityGroup
        - IpProtocol: tcp
          FromPort: 22
          ToPort: 22
          CidrIp: 0.0.0.0/0
      SecurityGroupEgress:
        - IpProtocol: "-1"
          CidrIp: 0.0.0.0/0

  AppSecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupDescription: Allow HTTP to Api app host
      # replace the vpc id
      VpcId: vpc-08a64dd4d4688a77d
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 5000
          ToPort: 5000
          CidrIp: 0.0.0.0/0
        - IpProtocol: tcp
          FromPort: 22
          ToPort: 22
          CidrIp: 0.0.0.0/0
        - IpProtocol: tcp
          FromPort: 9100
          ToPort: 9100
          SourceSecurityGroupId: !Ref PrometheusSecurityGroup
        - IpProtocol: tcp
          FromPort: 80
          ToPort: 80
          CidrIp: 0.0.0.0/0
        - IpProtocol: tcp
          FromPort: 443
          ToPort: 443
          CidrIp: 0.0.0.0/0
  CrashAppSecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupDescription: Allow HTTP to Crash-App host
      # replace the vpc id
      VpcId: vpc-08a64dd4d4688a77d
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 80
          ToPort: 80
          CidrIp: 0.0.0.0/0
        - IpProtocol: tcp
          FromPort: 443
          ToPort: 443
          CidrIp: 0.0.0.0/0
        - IpProtocol: tcp
          FromPort: 22
          ToPort: 22
          CidrIp: 0.0.0.0/0
      SecurityGroupEgress:
        - IpProtocol: "-1"
          CidrIp: 0.0.0.0/0
```

- To create the ec2 instances for grafana, promethues and flask app  paste the following in `main.yaml` don't forget to replace the elastic ip allocation id in `AllocationId` and replace with the public subnet id that you have in your vpc

```yaml
  PrometheusInstance:
    Type: AWS::EC2::Instance
    Properties:
      InstanceType: t3.micro
      ImageId: ami-0ae8f15ae66fe8cda 
      KeyName: TestKey
      BlockDeviceMappings:
        - DeviceName: /dev/sda1
          Ebs:
            VolumeSize: 20
            VolumeType: gp2
      NetworkInterfaces:
        - AssociatePublicIpAddress: 'true'
          DeviceIndex: '0'
          # replace the public from your vpc subnet id 
          SubnetId: subnet-082b90c734344d0e1
          GroupSet:
            - !Ref PrometheusSecurityGroup

  EIPAssociationPromethues:
    Type: 'AWS::EC2::EIPAssociation'
    Properties:
      InstanceId: !Ref PrometheusInstance
      # replace your elastic ip allocation  id here
      AllocationId: eipalloc-04eb7fe5d301399c0

  GrafanaInstance:
    Type: AWS::EC2::Instance
    Properties:
      InstanceType: t3.micro
      ImageId: ami-04a81a99f5ec58529
      KeyName: TestKey
      BlockDeviceMappings:
        - DeviceName: /dev/sda1
          Ebs:
            VolumeSize: 20
            VolumeType: gp2
      NetworkInterfaces:
        - AssociatePublicIpAddress: 'true'
          DeviceIndex: '0'
          # replace the public from your vpc subnet id
          SubnetId: subnet-08c5127c033604fb8
          GroupSet:
            - !Ref GrafanaSecurityGroup
      Tags:
        - Key: Name
          Value: Grafana
  
  EIPAssociationGrafana:
    Type: 'AWS::EC2::EIPAssociation'
    Properties:
      InstanceId: !Ref GrafanaInstance
       # replace your elastic ip allocation  id here
      AllocationId: eipalloc-029f173a1a1df9837

  CrashAppServer:
    Type: AWS::EC2::Instance
    Properties:
      InstanceType: t3.micro
      ImageId: ami-04a81a99f5ec58529
      KeyName: TestKey
      BlockDeviceMappings:
        - DeviceName: /dev/sda1
          Ebs:
            VolumeSize: 20
            VolumeType: gp2
      NetworkInterfaces:
        - AssociatePublicIpAddress: 'true'
          DeviceIndex: '0'
          # replace the public from your vpc subnet id
          SubnetId: subnet-08c5127c033604fb8
          GroupSet:
            - !Ref CrashAppSecurityGroup
      Tags:
        - Key: Name
          Value: Crash-App
  
  EIPAssociationGrafana:
    Type: 'AWS::EC2::EIPAssociation'
    Properties:
      InstanceId: !Ref CrashAppServer
       # replace your elastic ip allocation  id here
      AllocationId: eipalloc-xxxxxxxxxxxxx
              
```

- **Now we create the individual configuration to setup the server configuration using ansible and we will use ansible roles**

    - Inside your `ansible` create a `ansible.cfg` file `touch ./ansible/ansible.cfg` inside we are disablling the `host_key_checking`
      ```conf
       [defaults]
       host_key_checking = False
      ```    
    - Now we create a `inventory` inside `ansible` folder `touch ./ansible/inventory` we are creating the `ansible_user` in inventory file to serve the server dynamically, change the ip addresses for respective server this will be our `elastic ip` 
    ```yaml
    [grafana]
    100.29.106.209 ansible_user=ubuntu
    [prometheus]
    44.203.140.254 ansible_user=ubuntu 
    [crashapi]
    44.203.140.254 ansible_user=ubuntu
    ```
    - Create `main.yaml` inside `ansible` folder `touch ./ansible/main.yaml`  we are deploying multiple host for `grafana`, `promethues`, `crashapi` paste to following inside `./ansible/main.yaml` 
```yaml
---
- hosts: grafana
  become: true
 
  tasks:
    - name: Install Grafana
      include_role:
        name: grafana
        
- hosts: prometheus
  become: true
 
  tasks:
    - name: Install Prometheus
      include_role:
        name: prometheus

- hosts: crashapi
  become: true
 
  tasks:
    - name: Install CrashAPI
      include_role:
        name: crashapi
```

**1.Paste the following to configure app, node_exporter and nginx in `./ansible/roles/crashapi/tasks/main.yml`**



```yaml
---
- name: Installing the flask app and creating the systemd service
  import_tasks: install-app.yml

- name: Installing the node exporter and creating the systemd service
  import_tasks: node_exporter.yml

- name: Install nginx and configure ssl
  import_tasks: nginx.yml
```

**2. Create a file  `touch ./ansible/roles/crashapi/tasks/install-app.yml` and Paste the following to configure app in `./ansible/roles/crashapi/tasks/install-app.yml`**


```yaml
- name: Update package lists (on Debian/Ubuntu)
  apt:
    update_cache: yes

- name: Install Python3, pip, and venv
  apt:
    name: "{{ item }}"
    state: latest
    update_cache: yes
  loop: "{{ packages }}"

- name: Manually create the initial virtualenv
  command: python3 -m venv "{{ venv_dir }}"
  args:
    creates: "{{ venv_dir }}"

- name: Clone a GitHub repository
  git:
    repo: https://github.com/roeeelnekave/flask-crash-api.git
    dest: "{{ app_dir }}"
    clone: yes
    update: yes

- name: Install requirements inside the virtual environment
  command: "{{ venv_dir }}/bin/pip install -r {{ app_dir }}/requirements.txt"
  become: true

- name: Ensure application directory exists
  file:
    path: "{{ app_dir }}"
    state: directory
    owner: "{{ user }}"
    group: "{{ group }}"

- name: Ensure virtual environment directory exists
  file:
    path: "{{ venv_dir }}"
    state: directory
    owner: "{{ user }}"
    group: "{{ group }}"

- name: Create systemd service file
  template:
    src: crashapi.service.j2
    dest: /etc/systemd/system/{{ service_name }}.service
  become: true

- name: Reload systemd to pick up the new service
  systemd:
    daemon_reload: yes

- name: Start and enable the Flask app service
  systemd:
    name: "{{ service_name }}"
    state: started
    enabled: yes

- name: Check status of the Flask app service
  command: systemctl status {{ service_name }}
  register: service_status
  ignore_errors: yes

- name: Display service status
  debug:
    msg: "{{ service_status.stdout_lines }}"
```


**3. Create a file  `touch ./ansible/roles/crashapi/tasks/node_exporter.yml` and Paste the following to configure node_exporter in `./ansible/roles/crashapi/tasks/node_exporter.yml`**


```yaml
- name: Download Node Exporter binary
  get_url:
    url: https://github.com/prometheus/node_exporter/releases/download/v1.0.1/node_exporter-1.0.1.linux-amd64.tar.gz
    dest: /tmp/node_exporter-1.0.1.linux-amd64.tar.gz

- name: Create Node Exporter group
  group:
    name: node_exporter
    state: present

- name: Create Node Exporter user
  user:
    name: node_exporter
    group: node_exporter
    shell: /sbin/nologin
    create_home: no

- name: Create Node Exporter directory
  file:
    path: /etc/node_exporter
    state: directory
    owner: node_exporter
    group: node_exporter

- name: Unpack Node Exporter binary
  unarchive:
    src: /tmp/node_exporter-1.0.1.linux-amd64.tar.gz
    dest: /tmp/
    remote_src: yes

- name: Remove the Node Exporter binary if it exists
  file:
    path: /usr/bin/node_exporter
    state: absent

- name: Install Node Exporter binary
  copy:
    src: "/tmp/node_exporter-1.0.1.linux-amd64/node_exporter"
    dest: /usr/bin/node_exporter
    owner: node_exporter
    group: node_exporter
    mode: '0755'
  remote_src: yes
  become: true

- name: Create Node Exporter service file
  template:
    src: nodeexporter.service.j2
    dest: /usr/lib/systemd/system/node_exporter.service
  become: true

- name: Reload systemd
  systemd:
    daemon_reload: yes

- name: Start Node Exporter service
  systemd:
    name: node_exporter
    state: started
    enabled: yes

- name: Clean up
  file:
    path: /tmp/node_exporter-1.0.1.linux-amd64.tar.gz
    state: absent
  when: clean_up is defined and clean_up
```

**4. Create a file  `touch ./ansible/roles/crashapi/tasks/nginx.yml` and Paste the following to configure nginx in `./ansible/roles/crashapi/tasks/nginx.yml`**


```yaml
---
- name: Update the apt package index
  apt:
    update_cache: yes

- name: Install Nginx and certbot
  apt:
    name:
      - nginx
      - certbot
      - python3-certbot-nginx
    state: present

- name: Remove nginx default configuration
  file:
    path: /etc/nginx/sites-enabled/default
    state: absent

- name: Copy Nginx configuration
  template:
    src: app.conf.j2
    dest: /etc/nginx/sites-available/crash-api.conf

- name: Enable Nginx configuration for Crash-api
  file:
    src: /etc/nginx/sites-available/crash-api.conf
    dest: /etc/nginx/sites-enabled/crash-api.conf
    state: link
  become: true

- name: Test Nginx configuration
  command: nginx -t
  become: true

- name: Restart Nginx
  service:
    name: nginx
    state: restarted
  become: true

- name: Obtain SSL certificate
  shell: certbot --nginx -d crash.roeeelnekave.online --non-interactive --agree-tos --email roeeelnekave@gmail.com
  become: true
```

**5. Create a varaiable to load on our files `./ansible/roles/crashapi/vars/main.yml` and paste the following in this file**


```yaml
---
# vars file for crashapi
app_dir: /home/ubuntu/flask-crash-api
venv_dir: /home/ubuntu/flaskenv
gunicorn_config: /home/ubuntu/flask-crash-api/gunicorn.py
service_name: myflaskapp
user: ubuntu
group: ubuntu
packages:
  - python3
  - python3-pip
  - python3-venv
```

**6. To create a nginx config for app, create the   `touch ./ansible/roles/crashapi/templates/app.conf.j2` and paste the following in `./ansible/roles/crashapi/templates/app.conf.j2`**


```conf
server {
  listen 80;
  server_name crash.roeeelnekave.online; 

  location / {
    proxy_pass http://localhost:5000;  # Forward requests to Flask app
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
  }
}
```
**7. To create a systemd service for app, create the   `touch ./ansible/roles/crashapi/templates/crashapi.service.j2` and paste the following in `./ansible/roles/crashapi/templates/crashapi.service.j2`**

```bash
[Unit]
Description=Gunicorn instance to serve myflaskapp
After=network.target

[Service]
User={{ user }}
Group={{ group }}
WorkingDirectory={{ app_dir }}
ExecStart={{ venv_dir }}/bin/gunicorn -c {{ gunicorn_config }} app:app

[Install]
WantedBy=multi-user.target
```
**8. To create a systemd service for app, create the   `touch ./ansible/roles/crashapi/templates/nodeexporter.service.j2` and paste the following in `./ansible/roles/crashapi/templates/nodeexporter.service.j2`**


```bash
[Unit]
Description=Node Exporter
Documentation=https://prometheus.io/docs/guides/node-exporter/
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
Restart=on-failure
ExecStart=/usr/bin/node_exporter \
  --web.listen-address=:9200

[Install]
WantedBy=multi-user.target
```

### Now let's configure instance for the grafana

1. **to configure grafana paste the following in this file `./ansible/roles/grafana/tasks/main.yml`**



```yaml
---

- name: Update Packages
  apt:
    update_cache: yes
  tags: packages

- name: Install Packages
  apt:
    name: "{{ item }}"
    state: present
  loop: "{{ packages }}"
  tags: packages

- name: Ensure /etc/apt/keyrings/ directory exists
  file:
    path: /etc/apt/keyrings/
    state: directory
    mode: '0755'
  become: true
  tags: create_directory

- name: Download Grafana GPG key
  ansible.builtin.get_url:
    url: https://apt.grafana.com/gpg.key
    dest: /tmp/grafana.gpg.key
  tags: download_gpg_key

- name: Convert Grafana GPG key to binary format
  ansible.builtin.command: |
    gpg --dearmor -o /etc/apt/keyrings/grafana.gpg /tmp/grafana.gpg.key
  become: true
  tags: dearmor_gpg_key

- name: Clean up temporary GPG key file
  ansible.builtin.file:
    path: /tmp/grafana.gpg.key
    state: absent
  tags: cleanup_gpg_key

- name: Add Grafana stable repository
  ansible.builtin.lineinfile:
    path: /etc/apt/sources.list.d/grafana.list
    line: 'deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main'
    create: yes
  become: true
  tags: add_stable_repo

- name: Add Grafana beta repository (optional)
  ansible.builtin.lineinfile:
    path: /etc/apt/sources.list.d/grafana.list
    line: 'deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com beta main'
    create: yes
  become: true
  tags: add_beta_repo

- name: Update the list of available packages
  ansible.builtin.apt:
    update_cache: yes
  become: true
  tags: update_package_list

- name: Install grafana
  apt:
    name: "{{ item }}"
    state: present
  loop: "{{ grafana }}"
  tags: grafana

- name: Ensure Grafana server is enabled and started
  ansible.builtin.systemd:
    name: grafana-server
    enabled: yes
    state: started
  become: true
  tags: grafana_server

- name: Check Grafana server status
  ansible.builtin.systemd:
    name: grafana-server
    state: started
  register: grafana_status
  become: true
  tags: check_grafana_status

- name: Display Grafana server status
  ansible.builtin.debug:
    var: grafana_status
  tags: display_grafana_status

- name: Remove default Nginx configuration
  file:
    path: /etc/nginx/sites-enabled/default
    state: absent
  become: true
  tags: remove_default_nginx_config

- name: Deploy Grafana Nginx configuration
  template:
    src: grafana.conf.j2
    dest: /etc/nginx/sites-available/grafana.conf

- name: Enable Grafana Nginx configuration
  file:
    src: /etc/nginx/sites-available/grafana.conf
    dest: /etc/nginx/sites-enabled/grafana.conf
    state: link
  become: true
  tags: enable_grafana_nginx_config

- name: Test Nginx configuration
  command: nginx -t
  become: true
  tags: test_nginx_config

- name: Restart Nginx
  service:
    name: nginx
    state: restarted
  become: true
  tags: restart_nginx

- name: Obtain SSL certificates with Certbot
  command: certbot --nginx -d {{ domain_name }} --non-interactive --agree-tos --email {{ email }}
  register: certbot_result
  ignore_errors: true
  become: true
```

2. **To set the variables paste the following in `./ansible/roles/grafana/vars/main.yml`**


```yaml
---

packages:
  - apt-transport-https
  - software-properties-common
  - wget
  - nginx
  - certbot
  - python3-certbot-nginx

grafana:
  - grafana
  - grafana-enterprise

domain_name: "grafana.example.com"
email: "example@example.com"
```

3. **To configure the grafana with nginx create the file `touch ./ansible/roles/grafana/templates/grafana.conf.j2` and paste the following in `./ansible/roles/grafana/templates/grafana.conf.j2`**

```conf
server {
    listen 80;
    server_name {{ domain_name }};  # Replace with your domain or IP address

    location / {
        proxy_pass http://localhost:3000;  # Forward requests to Grafana
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Optional: Handle WebSocket connections for Grafana Live
    location /api/live/ {
        proxy_pass http://localhost:3000/api/live/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
    }
}
```

### Configure the Promethues server with ansible

1.**Paste the following in `./ansible/roles/prometheus/tasks/main.yml`**

```yaml
---
- name: Update system packages
  apt:
    update_cache: yes

- name: Create a system group for Prometheus
  group:
    name: "{{ prometheus_group }}"
    system: yes

- name: Create a system user for Prometheus
  user:
    name: "{{ prometheus_user }}"
    shell: /sbin/nologin
    system: yes
    group: "{{ prometheus_group }}"

- name: Create directories for Prometheus
  file:
    path: "{{ item }}"
    state: directory
    owner: "{{ prometheus_user }}"
    group: "{{ prometheus_group }}"
  loop:
    - "{{ prometheus_config_dir }}"
    - "{{ prometheus_data_dir }}"

- name: Download Prometheus
  get_url:
    url: "https://github.com/prometheus/prometheus/releases/download/v{{ prometheus_version }}/prometheus-{{ prometheus_version }}.linux-amd64.tar.gz"
    dest: /tmp/prometheus.tar.gz

- name: Extract Prometheus
  unarchive:
    src: /tmp/prometheus.tar.gz
    dest: /tmp/
    remote_src: yes

- name: Move Prometheus binaries
  command: mv /tmp/prometheus-{{ prometheus_version }}.linux-amd64/{{ item }} "{{ prometheus_install_dir }}/"
  loop:
    - prometheus
    - promtool

- name: Remove existing console_libraries directory
  file:
    path: "{{ prometheus_config_dir }}/console_libraries"
    state: absent
    
- name: Remove existing console directory
  file:
    path: "{{ prometheus_config_dir }}/consoles"
    state: absent

- name: Remove existing prometheus.yml file
  file:
    path: "{{ prometheus_config_dir }}/prometheus.yml"
    state: absent

- name: Move configuration files
  command: mv /tmp/prometheus-{{ prometheus_version }}.linux-amd64/{{ item }} "{{ prometheus_config_dir }}/"
  loop:
    - prometheus.yml
    - consoles
    - console_libraries


- name: Set ownership for configuration files
  file:
    path: "{{ prometheus_config_dir }}/{{ item }}"
    owner: "{{ prometheus_user }}"
    group: "{{ prometheus_group }}"
    state: directory
  loop:
    - consoles
    - console_libraries

- name: Create Prometheus systemd service file
  template:
    src: prometheus.service.j2
    dest: /etc/systemd/system/prometheus.service
  become: true

- name: Reload systemd
  command: systemctl daemon-reload
  become: true

- name: Enable and start Prometheus service
  systemd:
    name: prometheus
    enabled: yes
    state: started
  become: true 
```
2. **To set default varaibles paste the following in `./ansible/roles/prometheus/defaults/main.yml` don't forget to replace `crash_api_ip` with your application server ip**
```yaml
---
prometheus_version: "2.54.0"
prometheus_user: "prometheus"
prometheus_group: "prometheus"
prometheus_install_dir: "/usr/local/bin"
prometheus_config_dir: "/etc/prometheus"
prometheus_data_dir: "/var/lib/prometheus"
crash_api_ip: "127.0.0.1"
```
3. **To create a services for systemd create a file in  `touch ./ansible/roles/prometheus/templates/promethues.service.j2` and paste the following `./ansible/roles/prometheus/templates/promethues.service.j2`**
```bash
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User={{ prometheus_user }}
Group={{ prometheus_group }}
Type=simple
ExecStart={{ prometheus_install_dir }}/prometheus \
  --config.file {{ prometheus_config_dir }}/prometheus.yml \
  --storage.tsdb.path {{ prometheus_data_dir }} \
  --web.console.templates={{ prometheus_config_dir }}/consoles \
  --web.console.libraries={{ prometheus_config_dir }}/console_libraries

[Install]
WantedBy=multi-user.target

```
4. **To create a promethues configuration create a file in  `touch ./ansible/roles/prometheus/templates/promethues.yml.j2` and paste the following `./ansible/roles/prometheus/templates/promethues.yml.j2`**

```yaml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
  - job_name: 'crash-api'
    static_configs:
      - targets: ['{{ crash_api_ip }}:9100']
```

### Now let's create the python app
1. **Create `./app.py` in root directory of your project and paste the following**
```python
from flask import Flask, request, render_template, jsonify, redirect
import requests

app = Flask(__name__)

# Route for the input form
@app.route('/', methods=['GET', 'POST'])
def index():
    if request.method == 'POST':
        state_case = request.form['stateCase']
        case_year = request.form['caseYear']
        state = request.form['state']
        return redirect(f'/results?stateCase={state_case}&caseYear={case_year}&state={state}')
    return render_template('index.html')

# Route for displaying results
@app.route('/results')
def results():
    state_case = request.args.get('stateCase')
    case_year = request.args.get('caseYear')
    state = request.args.get('state')
    
    # Call the NHTSA Crash API
    url = f"https://crashviewer.nhtsa.dot.gov/CrashAPI/crashes/GetCaseDetails?stateCase={state_case}&caseYear={case_year}&state={state}&format=json"
    response = requests.get(url)
    
    if response.status_code != 200:
        return render_template('results.html', data={"error": "Failed to retrieve data from the API."})

    data = response.json()  # Assuming the API returns JSON data

    return render_template('results.html', data=data)

# API endpoint for cURL
@app.route('/api/crashdata', methods=['GET'])
def api_crashdata():
    state_case = request.args.get('stateCase')
    case_year = request.args.get('caseYear')
    state = request.args.get('state')
    
    # Call the NHTSA Crash API
    url = f"https://crashviewer.nhtsa.dot.gov/CrashAPI/crashes/GetCaseDetails?stateCase={state_case}&caseYear={case_year}&state={state}&format=json"
    response = requests.get(url)
    
    if response.status_code != 200:
        return jsonify({"error": "Failed to retrieve data from the API."}), response.status_code

    data = response.json()

    return jsonify(data)

if __name__ == '__main__':
    app.run(debug=True)
```
2. **Create `./guniucorn.py` and paste following**:
```python
bind = "0.0.0.0:5000"
workers = 2
```
3. **Create a html to load template `touch ./templates/index.html` and paste the following `./templates/index.html`**

```html
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Crash Data Input</title>
        </head>
        <body>
            <h1>Enter Crash Data Parameters</h1>
            <form method="POST">
                <label for="stateCase">State Case:</label>
                <input type="text" id="stateCase" name="stateCase" required>
                
                <label for="caseYear">Case Year:</label>
                <input type="text" id="caseYear" name="caseYear" required>
                
                <label for="state">State:</label>
                <input type="text" id="state" name="state" required>
                
                <button type="submit">Submit</button>
            </form>
        </body>
        </html>
```
4.  **Create a html to load template `touch ./templates/results.html` and paste the following `./templates/results.html`**
```html
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Crash Data Results</title>
        </head>
        <body>
            <h1>Crash Data Results</h1>
            <pre>{{ data | tojson(indent=2) }}</pre>
            <a href="/">Go Back</a>
        </body>
        </html>
```
5. **Create a `./requirements.txt` file and paste the following**
```bash
blinker==1.8.2
certifi==2024.7.4
charset-normalizer==3.3.2
click==8.1.7
Flask==3.0.3
idna==3.7
itsdangerous==2.2.0
Jinja2==3.1.4
MarkupSafe==2.1.5
requests==2.32.3
urllib3==2.2.2
Werkzeug==3.0.3
gunicorn
```
### Now create a jenkins pipeline script 
1. Create a `./Jenkinsfile` inside the root directory of the project

```groovy
pipeline{
    agent { label 'ansible' }
    stages{
        stage("deploy main cloud formation")
        {
            steps {
                script {
                    // Run the AWS CloudFormation create-stack command
                    def createStack = sh(
                        script: 'aws cloudformation create-stack --stack-name grafanaPrometheus --template-body file://cloudformation/main.yaml',
                        returnStatus: true
                    )

                    // Check if the create-stack command was successful
                    if (createStack == 0) {
                        echo "CloudFormation stack creation started successfully."

                        // Wait for the stack creation to complete
                        def waitForStack = sh(
                            script: 'aws cloudformation wait stack-create-complete --stack-name grafanaPrometheus',
                            returnStatus: true
                        )

                        // Check if the wait command was successful
                        if (waitForStack == 0) {
                            echo "CloudFormation stack creation completed successfully."
                        } else {
                            error "Failed to wait for CloudFormation stack creation to complete."
                        }
                    } else {
                        error "Failed to create CloudFormation stack."
                    }
                }
            }
        }
        stage("deploy grafana, promethues and crash api server")
        {
            steps{
               dir('ansible'){
                sh "chmod 400 TestKey.pem"
                sh "ansible-playbook -i inventory --private-key TestKey.pem main.yml"
               }
            }

        }
    }
}
```
## Do a git push
```bash
git add .
git commit -m "Adding the required files"
git push
```
### Running the pipeline first create a ec2 to launch an ec2 

## Create an AWS EC2 Instance with 15GB Storage and SSH Access



### Steps

1. **Sign in to the AWS Management Console** and open the Amazon EC2 console at https://console.aws.amazon.com/ec2/

2. **Choose "Launch Instance"** to start the instance creation process

3. **Select "Ubuntu" as the Amazon Machine Image (AMI)**

4. **Choose an instance type** like "t2.micro" that fits your needs
5. **Choose a key pair** or either create new  if you create new key pair give it a name like `agentkey` click **Create key pair** 
6. **Leave all to default**

5. **Under "Configure Instance"**:
   - **Keep the default network settings**
   - **Expand "Add Storage"** and change the Size (GiB) to 15
   - **Keep other settings as default**

6. **Under "Configure Security Group"**:
   - **Select "Create a new security group"**
   - **Set a meaningful name and description**
   - **Add a rule to allow SSH access** from your IP address by setting "Source" to "My IP"

7. **Review your instance configuration** and click "Launch" to start the instance

8. **Select the instance in the EC2 console** and click "Connect" to get the SSH command

9. **Open a terminal** and run the SSH command using your key pair file replace the `ec2-198-51-100-1.compute-1.amazonaws.com` with actual ip of your ec2:

```bash
ssh -i ~/Downloads/agentkey.pem ubuntu@ec2-198-51-100-1.compute-1.amazonaws.com
```

10. **When prompted**, type "yes" to continue connecting

11. **You are now connected to your Ubuntu EC2 instance** via SSH

### Next Steps
- **Update and install packages** on your instance as needed
- **Attach additional storage volumes** or network interfaces
- **Configure monitoring and logging**
- **When done, remember to stop or terminate the instance** to avoid incurring charges

### Troubleshooting
- **Ensure your key pair file has the correct permissions**: `chmod 400 /path/to/key-pair.pem`
- **Check your security group rules** allow the necessary inbound and outbound traffic
- **Verify the instance status checks** have passed before attempting to connect

#### Steps to Create Access Key and Secret Key
1. Sign in to the AWS Management Console:
2. Go to the AWS Management Console at https://aws.amazon.com/console/.
3. Enter your account credentials to log in.
4. Navigate to IAM:
5. In the AWS Management Console, search for "IAM" in the services search bar and select IAM.
6. Select Users:
7. In the IAM dashboard, click on Users in the left navigation pane.
8. Choose the User:
9. Click on the name of the user for whom you want to create access keys. If you need to create a a new user, click on Add user, enter a username, and select Programmatic access.
10. Access Security Credentials:
11. After selecting the user, click on the Security credentials tab.
12. Create Access Key:
    - In the Access keys section, click on Create access key.
    - If the button is disabled, it means the user already has two active access keys, and you will need to delete one before creating a new one.
13. Configure Access Key:
   - You will be directed to a page that provides options for creating the access key. You can optionally add a description to help identify the key later.
14. Click on Create access key.
15. Retrieve Access Key:
   - After the access key is created, you will see the Access key ID and Secret access key.
**Important: This is your only opportunity to view or download the secret access key. Click Show to reveal it or choose to Download .csv file to save it securely.**
16. Secure Your Keys:
    - Store the access key ID and secret access key in a secure location. Do not share these keys publicly or hard-code them into your applications.
17. Complete the Process:
    - After saving your keys, click Done to finish the process.
**Important Notes**
**Access Key ID: This is a public identifier and can be shared.**
**Secret Access Key: This should be kept confidential and secure. If you lose it, you must create a new access key.**
**You can have a maximum of two access keys per IAM user. If you need more, deactivate or delete existing keys.**

12. **Now run the following script replace `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` values to according to access key and secret key that you have just created also we can replace `AWS_REGION`**

```bash
#!/bin/bash
sudo apt update
sudo apt install awscli -y
sudo apt install python3-pip -y
sudo apt install python3-venv -y
sudo apt install ansible -y

# Prompt for AWS credentials and region
AWS_ACCESS_KEY_ID=AKIAXXXXXXXXXXXX
AWS_SECRET_ACCESS_KEY=XXXXXXXXXXXXX
AWS_REGION=us-east-1

# Configure AWS CLI
aws configure set aws_access_key_id "$AWS_ACCESS_KEY_ID"
aws configure set aws_secret_access_key "$AWS_SECRET_ACCESS_KEY"
aws configure set region "$AWS_REGION"

echo "AWS CLI has been configured successfully."
```
### Now configure your Jenkins to run the pipeline 

1. Access your Jenkins server 
2. Click on **Manage Jenkins**.
3. Click on **Nodes**.
4. Click on **New Nodes**.
5. Give it a name as `ansible` and Check the Type `Permanent Agent` then click on **Create**.
6. Add **Remote root directory** as `/home/ubuntu`.
7. Add **Labels** as `ansible`.
8. On **Launch method** select `Launch agents via ssh`
9. On **Host** give the ip the agent server.
10. On **Credentials**  click on `Add` button select `Jenkins`.
11. On **Kind** select as `SSH username with private key`
12. On **ID** give it a unique name like `ubuntuagent`
13. On **Description** give it a Description like `agent to deploy grafana, promethues and application in aws`.
14. On **Username** give it the server username in our case it's `ubuntu`
15. On **Private Key** section select `Enter Directly` under key click `Add` and copy the contents of the keypair `agentkey.pem` and paste it there then click on **Add** 
16. Again in **Credentials** select the `id` of credentails that you have just created.
17. Under **Host Key Verification Strategy** select `Non verifying verification strategy`
18. Click on **Save**


**Now lets create a pipeline to deploy our application**

1. Go to Jenkins DashBoard
2. Click on **+ New Item**
3. Give it a name like `server-deployment`
4. Scroll Down to **Pipeline** select `Definition` as **Pipeline script from SCM**.
5. On **SCM** select **Git** on  **Repositories** give your repository url from github.
6. Under **Branches to build** in `Branch Specifier (blank for 'any')` edit that as `main` then Click on **Save**.
7. Click on **Build Now**
