/*
 * VORoleMapModule.java
 *
 * Created on March 29, 2005
 */

package gplazma.authz.plugins.vorolemap;

import java.security.cert.X509Certificate;
import java.util.*;

//import org.opensciencegrid.authz.ac.FQAN;
                                                                                                                                                                                                     
import org.globus.gsi.gssapi.GSSConstants;
import org.gridforum.jgss.ExtendedGSSContext;
import org.bouncycastle.asn1.x509.X509Name;
import org.globus.gsi.bc.X509NameHelper;
import org.apache.log4j.Logger;
import org.glite.voms.VOMSValidator;
import org.glite.voms.BasicVOMSTrustStore;
import org.glite.voms.VOMSAttribute;
import org.glite.voms.FQAN;
import org.glite.voms.ac.AttributeCertificate;
import gplazma.authz.util.X509CertUtil;


/**
 *
 *  @author Abhishek Singh Rana (with due acknowledgements to Vijay Sekhri for introducing me to EGEE VOMS)
 */
                                                                                                                                                                                                     
public class VORoleMapModule {
	
	static Logger log = Logger.getLogger(VORoleMapModule.class.getName());
    private static final boolean DEFAULT_VALIDATE_FLAG=false;
    private static final String DEFAULT_VOMSDIR="/etc/grid-security/certificates";
	VORoleMapExtract fineGrainExtract;
	private ExtendedGSSContext context;
	private String subjectDn;
	private X509Certificate[] chain;
	private boolean validate;
	private String dir;
	
	//constructor
	public VORoleMapModule(ExtendedGSSContext context)
	throws Exception {
		//System.out.println("- - -                 Activating     g P L A Z M A - l i t e    Suite                 - - - ");
		//System.out.println("- - -            Built-in Role-based fine grain Grid Authorization Service            - - - ");
		this.context = context;
	}

	private boolean assertContext(ExtendedGSSContext contextToCheck) {
		if (contextToCheck == null) {
			log.error("Context received by VORoleMapModule is null");
			return false;
        } 
		else {
			return true;
		}
	}

	public VORoleMapExtract getFineGrainExtract()
	throws Exception {
		boolean verifyContextFlag;
		verifyContextFlag = assertContext(context);
		
		if (verifyContextFlag == false) {
			return null;
		}
        String validateFromSys = System.getProperty("validate");
        String dir = System.getProperty("voms.cert.dir");
		
		if ((validateFromSys != null) && (validateFromSys.equals("false")))  {
			validate = false;
        }
		else {
			validate = DEFAULT_VALIDATE_FLAG;	
		}
        if ((dir == null) || ( dir.length() <= 0 )) {
            	dir = DEFAULT_VOMSDIR;
		}
		chain=(X509Certificate[])context.inquireByOid(GSSConstants.X509_CERT_CHAIN);
		if (chain == null) {
			return null;
		}

		for(int i=0;i< chain.length; i++) {
			X509Certificate cert=(X509Certificate)chain[i];
        }
			//following changed in new VOMS API
            VOMSValidator validator = X509CertUtil.getVOMSValidatorInstance();
            validator.setClientChain(chain);
            if(validate == true) {
            	validator=validator.validate();
           		if (!validator.isValidated()) {
            		return(null);
            	}
            }
                validator=validator.parse();
                Vector toReturn = new Vector();
                List listOfAttributes = validator.getVOMSAttributes();
                for (Iterator i = listOfAttributes.iterator(); i.hasNext(); ) {
                        VOMSAttribute vomsAttribute = (VOMSAttribute) i.next();
                        AttributeCertificate ac = vomsAttribute.getAC();
                        String issuer = ac.getIssuer().toString();
                        List listOfFqans = vomsAttribute.getFullyQualifiedAttributes();
                        for (Iterator j = listOfFqans.iterator(); j.hasNext(); ) {
                                String fqanStr = (String)j.next();
                                FQAN fqan = null;//new FQAN(issuer, fqanStr);
                                toReturn.add(fqan);
                        }
                }
                int numberOfFqans = toReturn.size();
                FQAN fqanToReturn[] = new FQAN[numberOfFqans];
                for (int i = 0; i < numberOfFqans; i++){
                        fqanToReturn[i] = (FQAN)toReturn.elementAt(i);
                }
		if (subjectDn == null) {
			subjectDn = X509NameHelper.toString((X509Name)chain[0].getSubjectDN());
			//following converts slashes to commas
			//subjectDn = chain[0].getSubjectDN().toString();
			int proxyIndex=subjectDn.indexOf("/CN=proxy");
			if(proxyIndex != -1) {
				subjectDn = subjectDn.substring(0,proxyIndex);
			}
		}
		fineGrainExtract = new VORoleMapExtract(subjectDn, fqanToReturn);
		log.info("- - -               Building fine-grain extract from ExtendedGSSContext               - - - ");
		return (fineGrainExtract);
        }


} //end of VORoleMapModule
 
