#include "etherShield.h"

// Configurable
static uint8_t mymac[6] = {0x54,0x55,0x58,0x10,0x00,0x24}; 
static uint8_t myip[4] = {10,15,4,222};

#define MYWWWPORT 80
#define BUFFER_SIZE 550
#define PAGING_INTERVAL 2000
//

static uint8_t buf[BUFFER_SIZE+1];
char screen1a[80] = "METRIX CREATE SPACE   hack       make";
char screen1b[80] = "METRIX CREATE SPACE   build    create";
char screen2a[80] = " Bottomless Toolbox      $5/hour";
char screen2b[80] = "        Free     Intertubes";
char screen3a[80] = " Open Noon-Midnight      Everyday";
char screen3b[80] = " Open Noon-Midnight     Come on in";

byte screenPage = 0;
unsigned long time1;
unsigned long time2;

EtherShield es=EtherShield();

void setup(){
  time1 = millis();
  
  Serial.begin(9600);
  Serial.println("Hello.");
  
  Serial1.begin(9600);
  Serial2.begin(9600);
  Serial3.begin(9600);

  // initialize enc28j60
  es.ES_enc28j60Init(mymac);
  
  Serial.println("initialized enc28j60");

  // init the ethernet/ip layer:
  es.ES_init_ip_arp_udp_tcp(mymac,myip, MYWWWPORT);
  
  Serial.println("initialized ethernet/ip layer");
}

void loop(){
  uint16_t dat_p;
  int8_t cmd;
  
  while(true) {
    time2 = millis();
    if (time1+PAGING_INTERVAL < millis()) {
      handle_scrolling();
      time1 = time2;
    }
    
    // read packet, handle ping and wait for a tcp packet:
    dat_p=es.ES_packetloop_icmp_tcp(buf,es.ES_enc28j60PacketReceive(BUFFER_SIZE, buf));

    //Serial.println("got a packet");

    /* dat_p will be unequal to zero if there is a valid 
     * http get */
    if(dat_p==0){
      // no http request
      continue;
    }
    // tcp port 80 begin
    if (strncmp("GET ",(char *)&(buf[dat_p]),4)!=0){
      //Serial.println("got an HTTP packet");
      // head, post and other methods:
      dat_p=http200ok();
      dat_p=es.ES_fill_tcp_data_p(buf,dat_p,PSTR("<h1>200 OK</h1>"));
      goto SENDTCP;
    }

    // root web page
    if (strncmp("/ ",(char *)&(buf[dat_p+4]),2)==0) {
      dat_p=print_webpage(buf);
      goto SENDTCP;
    } else if (strncmp("/?",(char *)&(buf[dat_p+4]),2)==0) {
      cmd = handle_get_url((char *)&(buf[dat_p+4]));

      if (cmd==2) {
        dat_p=print_webpage(buf);
        goto SENDTCP;
      }

      if (cmd==1) {
        refresh_display();
        dat_p=print_webpage(buf);
        goto SENDTCP;
      }
      goto SENDTCP;
    } else {
      dat_p=es.ES_fill_tcp_data_p(buf,0,PSTR("HTTP/1.0 401 Unauthorized\r\nContent-Type: text/html\r\n\r\n<h1>401 Unauthorized</h1>"));
      goto SENDTCP;
    }
    SENDTCP:
    es.ES_www_server_reply(buf,dat_p); // send web page data
    
  }

}

void handle_scrolling() {
  screenPage = ++screenPage % 2;
  time1 = millis();
  refresh_display();
}

void refresh_display() {
  if (screenPage == 0) {
    Serial1.print("\x15");
    Serial1.print(screen1a);
    Serial2.print("\x15");
    Serial2.print(screen2a);
    Serial3.print("\x15");
    Serial3.print(screen3a);
  } else {
    Serial1.print("\x15");
    Serial1.print(screen1b);
    Serial2.print("\x15");
    Serial2.print(screen2b);
    Serial3.print("\x15");
    Serial3.print(screen3b);
  }
}

int8_t handle_get_url(char *str) {
  uint8_t mn=0;

  // the first slash:
  if (str[0] == '/' && str[1] == ' '){
    // end of url, display just the web page
    return(2);
  }
  
  if ( (find_key_val(str, screen1a, 80, "screen1a") || true) &&
       (find_key_val(str, screen1b, 80, "screen1b") || true) &&
       (find_key_val(str, screen2a, 80, "screen2a") || true) &&
       (find_key_val(str, screen2b, 80, "screen2b") || true) &&
       (find_key_val(str, screen3a, 80, "screen3a") || true) &&
       (find_key_val(str, screen3b, 80, "screen3b") || true ))
    return(1);
  
  // browsers looking for /favion.ico, non existing pages etc...
  return(-1);
}

uint8_t find_key_val(char *str, char *strbuf, uint8_t maxlen, char *key) {
  uint8_t i;
  i = es.ES_find_key_val(str, strbuf, maxlen, key);
  es.ES_urldecode(strbuf);
  return i;
}


uint16_t http200ok(void) {
  return(es.ES_fill_tcp_data_p(buf,0,PSTR("HTTP/1.0 200 OK\r\nContent-Type: text/html\r\nPragma: no-cache\r\n\r\n")));
}

// prepare the webpage by writing the data to the tcp send buffer
uint16_t print_webpage(uint8_t *buf)
{
  uint16_t plen;
  plen=http200ok();
  plen=es.ES_fill_tcp_data_p(buf,plen,PSTR("<html><head><title>Metrix VFD</title>"));
  plen=es.ES_fill_tcp_data_p(buf,plen,PSTR("<script src=\"http://gir.seattlewireless.net/~andyf/hamburgerboard/hamburgerboard.js\"></script></head>"));

  /*plen=es.ES_fill_tcp_data_p(buf,plen,PSTR("<body><form>"));

  plen=es.ES_fill_tcp_data_p(buf,plen,PSTR("<input type=\"text\" name=\"screen1a\" />"));
  plen=es.ES_fill_tcp_data_p(buf,plen,PSTR("<input type=\"text\" name=\"screen1b\" /><hr/>"));

  plen=es.ES_fill_tcp_data_p(buf,plen,PSTR("<input type=\"text\" name=\"screen2a\" />"));
  plen=es.ES_fill_tcp_data_p(buf,plen,PSTR("<input type=\"text\" name=\"screen2b\" /><hr/>"));

  plen=es.ES_fill_tcp_data_p(buf,plen,PSTR("<input type=\"text\" name=\"screen3a\" />"));
  plen=es.ES_fill_tcp_data_p(buf,plen,PSTR("<input type=\"text\" name=\"screen3b\" /><hr/>"));

  plen=es.ES_fill_tcp_data_p(buf,plen,PSTR("<input type=\"submit\" value=\">>\" /></form>")); */
  plen=es.ES_fill_tcp_data_p(buf,plen,PSTR("<body></body></html>"));


  return(plen);
}




