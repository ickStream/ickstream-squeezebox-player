/*
 * Copyright (c) 2013, ickStream GmbH
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without 
 * modification, are permitted provided that the following conditions are met:
 *
 *   * Redistributions of source code must retain the above copyright 
 *     notice, this list of conditions and the following disclaimer.
 *   * Redistributions in binary form must reproduce the above copyright 
 *     notice, this list of conditions and the following disclaimer in the 
 *     documentation and/or other materials provided with the distribution.
 *   * Neither the name of ickStream nor the names of its contributors 
 *     may be used to endorse or promote products derived from this software 
 *     without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND 
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED 
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. 
 * IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, 
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, 
 * BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, 
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY 
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING 
 * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, 
 * EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <netdb.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <pthread.h>

#include "ickDiscovery.h"

int g_clientSocket = 0;
int g_serverSocket = 0;
static pthread_mutex_t g_receiveMutex = PTHREAD_MUTEX_INITIALIZER;

void onMessage(const char * szSourceDeviceId, const char * message, size_t messageLength, enum ickMessage_communicationstate state, ickDeviceServicetype_t service_type, const char * szTargetDeviceId)
{
	char MESSAGE[] = "MESSAGE\n";
	char END[] = "\n!END!\n";
	
	printf("onMessage called\n");
	fflush (stdout);
	pthread_mutex_lock(&g_receiveMutex);
	printf("Message from %s: %s\n", szSourceDeviceId,(const char *)message);
	fflush (stdout);
	if(g_clientSocket != 0) {
		size_t messageBufferSize = strlen(szSourceDeviceId)+messageLength+strlen(MESSAGE)+1+strlen(END);
		size_t deviceIdLength = strlen(szSourceDeviceId);
		char* messageBuffer = malloc(messageBufferSize+1);
		memcpy(messageBuffer,szSourceDeviceId,deviceIdLength);
		messageBuffer[deviceIdLength] = '\n';
		memcpy(messageBuffer+deviceIdLength+1,MESSAGE,strlen(MESSAGE));
		memcpy(messageBuffer+deviceIdLength+1+strlen(MESSAGE),message,messageLength);
		memcpy(messageBuffer+deviceIdLength+1+strlen(MESSAGE)+messageLength,END,strlen(END));
		messageBuffer[deviceIdLength+1+strlen(MESSAGE)+messageLength+strlen(END)]='\0';
		if(send(g_clientSocket,messageBuffer,messageBufferSize,0) != messageBufferSize) {
			fprintf(stderr, "Failed to write message from %s to socket: %s\n",szSourceDeviceId,(const char*)messageBuffer);
			fflush (stderr);
		}
		free(messageBuffer);
	}
	pthread_mutex_unlock(&g_receiveMutex);
}

void onDevice(const char * szDeviceId, enum ickDiscovery_command change, enum ickDevice_servicetype type)
{
	char DEVICE[] = "DEVICE\n";
	char ADD[] = "ADD\n";
	char DEL[] = "DEL\n";
	char UPD[] = "UPD\n";
	char END[] = "!END!\n";
	printf("onDevice called\n");
	fflush (stdout);
	pthread_mutex_lock(&g_receiveMutex);

	size_t deviceIdLength = strlen(szDeviceId);
	size_t messageBufferSize = deviceIdLength+strlen(DEVICE)+1+4+2+strlen(END);
	char* messageBuffer = malloc(messageBufferSize+1);
	memcpy(messageBuffer,szDeviceId,deviceIdLength);
	messageBuffer[deviceIdLength] = '\n';
	memcpy(messageBuffer+deviceIdLength+1,DEVICE,strlen(DEVICE));
	char *p = messageBuffer+deviceIdLength+1+strlen(DEVICE);
	*p = (int)'0'+type;
	p++;
	*p = '\n';

	int nWritten = 0;
	switch(change) {
		case ICKDISCOVERY_ADD_DEVICE:
			memcpy(messageBuffer+deviceIdLength+1+strlen(DEVICE)+2,ADD,strlen(ADD));
			memcpy(messageBuffer+deviceIdLength+1+strlen(DEVICE)+2+strlen(ADD),END,strlen(END));
			messageBuffer[deviceIdLength+1+strlen(DEVICE)+2+strlen(ADD)+strlen(END)]='\0';
			printf("New device %s of type %d\n",szDeviceId,type);
			if(g_clientSocket != 0) {
				if((nWritten = send(g_clientSocket,messageBuffer,messageBufferSize,0)) != messageBufferSize) {
					fprintf(stderr, "Failed to write message from %s to socket: %s\nOnly wrote %d characters out of %d",szDeviceId,(const char*)messageBuffer,nWritten,messageBufferSize);
					fflush (stderr);
				}
			}
			break;
		case ICKDISCOVERY_REMOVE_DEVICE:
			memcpy(messageBuffer+deviceIdLength+1+strlen(DEVICE)+2,DEL,strlen(DEL));
			memcpy(messageBuffer+deviceIdLength+1+strlen(DEVICE)+2+strlen(DEL),END,strlen(END));
			messageBuffer[deviceIdLength+1+strlen(DEVICE)+2+strlen(DEL)+strlen(END)]='\0';
			printf("Removed device %s\n",szDeviceId);
			if(g_clientSocket != 0) {
				if((nWritten = send(g_clientSocket,messageBuffer,messageBufferSize,0)) != messageBufferSize) {
					fprintf(stderr, "Failed to write message from %s to socket: %s\nOnly wrote %d characters out of %d\n",szDeviceId,(const char*)messageBuffer,nWritten,messageBufferSize);
					fflush (stderr);
				}
			}
			break;
		case ICKDISCOVERY_UPDATE_DEVICE:
			memcpy(messageBuffer+deviceIdLength+1+strlen(DEVICE)+2,UPD,strlen(UPD));
			memcpy(messageBuffer+deviceIdLength+1+strlen(DEVICE)+2+strlen(UPD),END,strlen(END));
			messageBuffer[deviceIdLength+1+strlen(DEVICE)+2+strlen(UPD)+strlen(END)]='\0';
			printf("Updated device %s of type %d\n",szDeviceId,type);
			if(g_clientSocket != 0) {
				if((nWritten = send(g_clientSocket,messageBuffer,messageBufferSize,0)) != messageBufferSize) {
					fprintf(stderr, "Failed to write message from %s to socket: %s\nOnly wrote %d characters out of %d\n",szDeviceId,(const char*)messageBuffer,nWritten,messageBufferSize);
					fflush (stderr);
				}
			}
			break;
		default:
			printf("Unknown message in device callback\n");
			break;
	}
	free(messageBuffer);
	pthread_mutex_unlock(&g_receiveMutex);
}
char* skipDelimiters(char* message) 
{
	while(*message == '\n' || *message == '\r' || *message == ' ' || *message == '\0') {
		message=message+1;
	}
	return message;
}

void handleShutdown() {
	if(g_serverSocket>0) {
		shutdown(g_serverSocket,2);
	}
}
void handleMessage(char* message) {
	message = skipDelimiters(message);

	char deviceId[100];
	int i=0;
	while(*message != '\0' && *message != '\n' && *message != '\r' && *message != ' ') {
		deviceId[i] = *message;
		message++;
		i++;
	}
	deviceId[i] = '\0';

	if(strcmp(deviceId,"ALL")==0) {
		printf("Sending notification %s\n",message);
	    int i=0;
	    while(i<10) {
			if(ickDeviceSendMsg(NULL,message,strlen(message)) == ICKMESSAGE_SUCCESS) {
	            break;
	        }
	        sleep(1);
	        i++;
	    }
	    if(i==10) {
	        printf("Failed to send notification\n");
	    }
	}else {
		printf("Sending message to %s: %s\n",deviceId, message);
	    int i=0;
	    while(i<10) {
			if(ickDeviceSendMsg(deviceId,message,strlen(message)) == ICKMESSAGE_SUCCESS) {
		        printf("Succeeded to send message after %d retries\n",i);
	            break;
	        }
	        sleep(1);
	        i++;
	    }
	    if(i==10) {
	        printf("Failed to send message\n");
	    }
	}
	fflush (stdout);
}

void handleInitialization(int socketfd, char* message) {
	
	message = skipDelimiters(message);

	char deviceId[100];
	int i=0;
	while(*message != '\0' && *message != '\n' && *message != '\r' && *message != ' ') {
		deviceId[i] = *message;
		message++;
		i++;
	}
	deviceId[i] = '\0';
	
	message = skipDelimiters(message);

	char networkAddress[100];
	i=0;
	while(*message != '\0' && *message != '\n' && *message != '\r' && *message != ' ') {
		networkAddress[i] = *message;
		message++;
		i++;
	}
	networkAddress[i] = '\0';

	message = skipDelimiters(message);

	char deviceName[255];
	i=0;
	while(*message != '\0' && *message != '\n' && *message != '\r') {
		deviceName[i] = *message;
		message++;
		i++;
	}
	deviceName[i] = '\0';

	printf("Initializing ickP2P for %s(%s) at %s...\n",deviceName,deviceId,networkAddress);
    g_clientSocket = socketfd;
    ickDeviceRegisterMessageCallback(&onMessage);
    ickDeviceRegisterDeviceCallback(&onDevice);
    ickInitDiscovery(deviceId, networkAddress,NULL);
    ickDiscoverySetupConfigurationData(deviceName, NULL);
    ickDiscoveryAddService(ICKDEVICE_PLAYER);
	fflush (stdout);
}

static void* client_thread(void *arg) {
    int *socketfd = (int *)arg;

	char buffer[8193];

	int nRead = 0;
	int offset = 0;
	while((nRead = read(*socketfd, buffer, 8192)) > 0) {
		offset = 0;
		buffer[nRead] = '\0';
		char *finalBuffer = malloc(nRead+1);
		memcpy(finalBuffer,buffer,nRead+1);
		while(nRead>0 && buffer[nRead-1] != '\0') {
			offset = offset + nRead;
			if((nRead = read(*socketfd, buffer, 8192))>0) {
				buffer[nRead] = '\0';
				char *newFinalBuffer = malloc(offset+nRead+1);
				memcpy(newFinalBuffer,finalBuffer,offset);
				memcpy(newFinalBuffer+offset,buffer,nRead+1);
				char *oldBuffer = finalBuffer;
				finalBuffer = newFinalBuffer;
				free(oldBuffer);
			}
		}
		printf("Processing ickSocketDaemon message\n");
		fflush (stdout);
		if(strncmp("MESSAGE",finalBuffer,7)==0) {
			handleMessage(finalBuffer+7);
		}else if(strncmp("INIT",finalBuffer,4)==0) {
			handleInitialization(*socketfd, finalBuffer+4);
		}else if(strncmp("SHUTDOWN",finalBuffer,8)==0) {
			handleShutdown();
			free(finalBuffer);
			break;
		}else {
			fprintf(stderr, "Unknown command %s",buffer);
			fflush (stderr);
		}
		free(finalBuffer);
	}
	close(*socketfd);
	free(socketfd);
	return 0;
}

int main( int argc, const char* argv[] )
{
	struct hostent     *he;
	// resolve localhost to an IP (should be 127.0.0.1)
	if ((he = gethostbyname("localhost")) == NULL) {
		fprintf(stderr, "Error resolving hostname..");
		fflush (stderr);
		return 1;
	}

	struct sockaddr_in addr;
    addr.sin_family = AF_INET;
    addr.sin_port = htons(20530);
	memcpy(&addr.sin_addr, he->h_addr_list[0], he->h_length);
	socklen_t addr_len = sizeof(addr);
	
	g_serverSocket = socket(AF_INET, SOCK_STREAM, 0);
	int opt = 1;
	setsockopt(g_serverSocket, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(int));
    setsockopt(g_serverSocket, SOL_SOCKET, SO_KEEPALIVE, &opt, sizeof(int));

    if (bind(g_serverSocket, (struct sockaddr *) &addr, sizeof(addr)) < 0) {
        fprintf(stderr, "Unable to bind to server socket");
		fflush (stderr);
        return 1;
    }

	listen(g_serverSocket,1);
	int socket;
    while((socket = accept(g_serverSocket,
                     (struct sockaddr *) &addr,
                     &addr_len))>=0) {

        int *client_socket = malloc(sizeof(int));
        *client_socket = socket;
        pthread_t handle;
        pthread_create(&handle, NULL, client_thread, client_socket);
    }
    close(g_serverSocket);

	if(g_clientSocket != 0) {
		close(g_clientSocket);
	}
	printf("Shutting down ickP2P...\n");
	fflush (stdout);
	ickEndDiscovery(1);
	fflush (stdout);
	return 0;
}	
