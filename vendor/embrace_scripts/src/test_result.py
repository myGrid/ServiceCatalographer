# ServiceCatalographer: /vendor/embrace_scripts/src/test_result.py
# ServiceCatalographer: vendor/embrace_scripts/biocat_wrapper.py
#
# Copyright (c) 2010, University of Manchester, The European Bioinformatics 
# Institute (EMBL-EBI) and the University of Southampton.
# See license.txt for details
# *************************************************************************

# Usage:
# Create a test result object and call the post
# method on it to post the results of a test script execution
# to a remote server. Underneath, it uses curl to post results
# to a url

import subprocess
import sys
from setup_logger import SetupLogger


class TestResult:
    def __init__(self, configs):
        self.configs = configs
        self.logger  = SetupLogger().logger("TestResult")
        
    def post(self, url, user, password):
        self.logger.info("posting result using curl")
        test_type ="TestScript"
        test_id   = self.configs['test_id']
        result    = self.configs['result']
        action    = self.configs['action']
        message   = self.configs['message']
        user      = user
        password  = password
    
        data = '<?xml version="1.0"?>' 
        data +='<test_result> '
        data +='<result>%d</result>'%(result)
        data +='<action>%s</action>'%(action)
        data +='<message>%s</message>'%(message)
        data +='<service_test_id>%d</service_test_id>'%(test_id)
        data +='</test_result>'   
        curl = "curl -X POST -u %s:%s -d '%s' -H 'Content-Type:application/xml' %s" %(user, password,data, url)
        #self.logger.debug(curl)
        #os.system(curl)
    
        try:
            retcode = subprocess.call(curl, shell=True)
            if retcode < 0:
                print >>sys.stderr, "Child was terminated by signal", -retcode
                return False
            elif retcode > 0:
                print >>sys.stderr, "There were problems with posting the result ", retcode
                #print >>sys.stderr, "Child returned", retcode
                return False
            else:
                print >> sys.stdout, "Result was posted successfully "
                return True
        except OSError, e:
                print >>sys.stderr, "Exception while posting result:", e
                return False
        return True
    
if __name__ == '__main__':
    conf = {
            'test_id'  :2769,
            'result'   :0,
            'action'   :'soaplab-2.2.typed.xml',
            'message'  :'Test OK'}
    
    url   = 'http://localhost:3000/test_results.xml'
    user  = "username@domain.whatever"
    psswd = "securepassword"
    
    res  = TestResult(conf)
    print res.post(url, user, psswd)