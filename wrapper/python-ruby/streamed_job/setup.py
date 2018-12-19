from distutils.core import setup

setup(
    name='streamed_job',
    version='0.1.0',
    author='Tyler Martin',
    author_email='tylernm@gmail.com',
    packages=['streamed_job'],
    scripts=['bin/run_streamed_job.py'],
    url='http://www.fakeurl.nowhere',
    license='LICENSE.txt',
    description='Run a process with a timeout and stream output to a db',
    long_description=open('README.txt').read(),
    install_requires=[
        "backports.tempfile",
        "backoff",
        "requests",
    ],
)
