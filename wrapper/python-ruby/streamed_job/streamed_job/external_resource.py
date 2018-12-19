import os
import requests
import backoff
import json

class ExternalResource(object):
    #  DAGGER_URL = os.environ['DAGGER_URL']
    #  RESOURCE_NAME = 'workflows'
    def __init__(self, resource_url, headers={}):
        #  self.resource_url = "{}/{}".format(DAGGER_URL, RESOURCE_NAME)
        self.resource_url = resource_url.rstrip('/')
        self.headers = headers

    @backoff.on_exception(backoff.expo, requests.exceptions.RequestException, max_tries = 8)
    def get(self):
        r = requests.get(self.resource_url, headers=self.headers)
        r.raise_for_status()
        return json.loads(r.text)

    @backoff.on_exception(backoff.expo, requests.exceptions.RequestException, max_tries = 8)
    def get(self, uri_path):
        r = requests.get(self.resource_url + uri_path, headers=self.headers)
        r.raise_for_status()
        return json.loads(r.text)

    @backoff.on_exception(backoff.expo, requests.exceptions.RequestException, max_tries = 8)
    def post_form(self, data={}, files={}):
        r = requests.post(self.resource_url, headers=self.headers, data=data, json='', files=files)
        r.raise_for_status()
        return json.loads(r.text)

    @backoff.on_exception(backoff.expo, requests.exceptions.RequestException, max_tries = 8)
    def update(self, id, attributes_hash):
        r = requests.put(self.resource_url + '/{}'.format(id), json=attributes_hash, headers=self.headers)
        r.raise_for_status()
        #  print "In external resource update"
        #  print r.text
        #  print r.status_code
        return json.loads(r.text)

    @backoff.on_exception(backoff.expo, requests.exceptions.RequestException, max_tries = 8)
    def delete(self, id):
        r = requests.delete(self.resource_url, '/{}'.format(id), headers=self.headers)
        r.raise_for_status()
        return json.loads(r.text)

class WorkflowResource(ExternalResource):
    def __init__(self):
        resource_url = os.environ['DAGGER_URL'].rstrip('/') + '/workflows'
        headers = { 'Authorization': 'Token token={}'.format(os.environ['ADMIN_TOKEN']) }
        super(WorkflowResource, self).__init__(resource_url, headers=headers)


class JobResource(ExternalResource):
    def __init__(self):
        resource_url = os.environ['DAGGER_URL'].rstrip('/') + '/jobs'
        headers = { 'Authorization': 'Token token={}'.format(os.environ['ADMIN_TOKEN']) }
        super(JobResource, self).__init__(resource_url, headers=headers)


class ResultResource(ExternalResource):
    def __init__(self):
        resource_url = os.environ['CELLAR_URL'].rstrip('/') + '/results'
        headers = { 'Authorization': 'Token token={}'.format(os.environ['ADMIN_TOKEN']) }
        super(ResultResource, self).__init__(resource_url, headers=headers)

class LocalInputResource(ExternalResource):
    def __init__(self):
        resource_url = os.environ['CELLAR_URL'].rstrip('/') + '/local_inputs'
        headers = { 'Authorization': 'Token token={}'.format(os.environ['ADMIN_TOKEN']) }
        super(LocalInputResource, self).__init__(resource_url, headers=headers)
