-- =====================================================================
-- LG전자 제품 판매 DB : MySQL 구현 및 분석
-- 데이터베이스관리 팀프로젝트에서 설계한 ERD와 SQL을 바탕으로 MySQL 8.x에서 구현
--
-- 사용법 (MySQL Workbench)
--   File > Open SQL Script 로 이 파일을 열고
--   번개 아이콘(Execute, Ctrl+Shift+Enter)을 누르면 처음부터 끝까지 실행됩니다.
--   결과는 아래 Result 탭에 쿼리별로 나옵니다.
--
-- 구성
--   STEP 1  스키마 생성
--   STEP 2  데이터 적재 (테이블별 원본 데이터 5개)
--   STEP 3  적재 검증 (건수·날짜·참조 무결성)
--   STEP 4  데이터 품질 점검 (예외 케이스)
--   STEP 5  요구조건별 쿼리 15개
--   STEP 6  CTE / 윈도우 함수 확장 분석
--
-- 컬럼명 대응 (한글 -> 영문)
--   고객   : 고객번호 customer_id, 이름 name, 전화번호 phone, 주소 address, 생년월일 birth_date, 직업 job
--   상품   : 모델명 model_name, 이름 product_name, 카테고리 category, 출시년월 release_ym, 판매가 price
--   제조사 : 사업자등록번호 biz_no, 회사명 company_name, 전화번호 phone, 주소 address, 이메일 email, 기업규모 company_size
--   제조   : 일련번호 serial_no, 모델명 model_name, 제조날짜 mfg_date, 제조단가 unit_cost,
--            불량여부 is_defective, 제조책임자 mfg_manager, 사업자등록번호 biz_no
--   주문   : 일련번호 serial_no, 고객번호 customer_id, 모델명 model_name, 주문날짜 order_date, 결제수단 payment_method
-- =====================================================================


-- =====================================================================
-- [STEP 1] 스키마 생성
-- =====================================================================
DROP DATABASE IF EXISTS lg_sales;
CREATE DATABASE lg_sales
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_0900_ai_ci;
USE lg_sales;

CREATE TABLE manufacturer (
  biz_no        VARCHAR(10)  PRIMARY KEY,
  company_name  VARCHAR(30)  NOT NULL,
  phone         VARCHAR(20),
  address       VARCHAR(50),
  email         VARCHAR(50),
  company_size  VARCHAR(10)
);

CREATE TABLE product (
  model_name    VARCHAR(20)  PRIMARY KEY,
  product_name  VARCHAR(100) NOT NULL,
  category      VARCHAR(20)  NOT NULL,
  release_ym    CHAR(7)      NOT NULL,          -- 'YYYY-MM'
  price         INT          NOT NULL
);

CREATE TABLE customer (
  customer_id   VARCHAR(10)  PRIMARY KEY,
  name          VARCHAR(20)  NOT NULL,
  phone         VARCHAR(20),
  address       VARCHAR(50),
  birth_date    DATE,
  job           VARCHAR(10)
);

-- 제조 : 제조된 제품 1대 = 1행
CREATE TABLE manufacture (
  serial_no     VARCHAR(20)  PRIMARY KEY,
  model_name    VARCHAR(20)  NOT NULL,
  mfg_date      DATE         NOT NULL,
  unit_cost     INT          NOT NULL,
  is_defective  TINYINT(1)   NOT NULL DEFAULT 0,  -- 0 = 정상, 1 = 불량
  mfg_manager   VARCHAR(20),
  biz_no        VARCHAR(10)  NOT NULL,
  CONSTRAINT fk_mfg_product      FOREIGN KEY (model_name) REFERENCES product(model_name),
  CONSTRAINT fk_mfg_manufacturer FOREIGN KEY (biz_no)     REFERENCES manufacturer(biz_no)
);

-- 주문 : 판매된 제품 1대 = 1행 (일련번호로 제조 이력과 연결)
CREATE TABLE orders (
  serial_no      VARCHAR(20) PRIMARY KEY,
  customer_id    VARCHAR(10) NOT NULL,
  model_name     VARCHAR(20) NOT NULL,
  order_date     DATE        NOT NULL,
  payment_method VARCHAR(10),
  CONSTRAINT fk_ord_customer FOREIGN KEY (customer_id) REFERENCES customer(customer_id),
  CONSTRAINT fk_ord_product  FOREIGN KEY (model_name)  REFERENCES product(model_name),
  CONSTRAINT fk_ord_mfg      FOREIGN KEY (serial_no)   REFERENCES manufacture(serial_no)
);

-- =====================================================================
-- [STEP 2] 데이터 적재 (data 폴더의 원본 데이터 5개)
--   참조되는 테이블부터: 제조사 -> 상품 -> 고객 -> 제조 -> 주문
-- =====================================================================

-- manufacturer: 32건
INSERT INTO manufacturer (biz_no, company_name, phone, address, email, company_size) VALUES
  ('A-1221', '조은개발', '031-121-1444', '대한민국 용인', 'goodgood@good.com', '대기업'),
  ('A-3222', '퍼니컴퍼니', '03-1241442', '중국 상하이', 'funfunny@funny.com', '중견기업'),
  ('B-1223', '일조컴퍼니', '03-7415125', '중국 충칭', 'onemillion@one.com', '중견기업'),
  ('B-1445', '해피컴퍼니', '05-3051007', '일본 도쿄', 'happyppy@hap.com', '중견기업'),
  ('B-4022', '부산공장', '051-461-1111', '대한민국 부산', 'busan0jang@jan.com', '중소기업'),
  ('C-0935', '스피드컴퍼니', '06-121-7412', '인도네시아 찌비뚱', 'speeeeeeed@run.com', '대기업'),
  ('C-6532', '신기공장', '055-121-7777', '대한민국 진주', 'singibanggi@sin.com', '대기업'),
  ('C-6766', '엄지개발', '031-741-4554', '대한민국 화성', 'thumbup@upup.com', '중견기업'),
  ('C-9833', '대현공장', '031-455-2121', '대한민국 수원', 'baehyun0o@bho.com', '중소기업'),
  ('D-1212', '미래컴퍼니', '031-121-5122', '대한민국 수원', 'mirae@cpo.com', '중견기업'),
  ('D-6335', '조선소재', '031-544-1211', '대한민국 용인', 'josunsun@som.com', '대기업'),
  ('D-7555', '한울공장', '055-877-1111', '대한민국 창원', 'hanwul12@han.com', '대기업'),
  ('E-1232', '라온기술', '055-121-7878', '대한민국 진주', 'laon7878@lan.com', '대기업'),
  ('F-1222', '신라개발', '03-1441-2145', '중국 상하이', 'sinsinrara@sinr.com', '대기업'),
  ('F-1323', '희망컴퍼니', '05-781-4144', '일본 도쿄', 'heeheehee@hh.com', '중견기업'),
  ('F-2364', '해운대공장', '051-322-2221', '대한민국 부산', 'haeundae@sea.com', '대기업'),
  ('F-4223', '키즈공장', '051-214-1217', '대한민국 부산', 'kids1217@gong.com', '중소기업'),
  ('G-1004', '번개공장', '03-3272345', '중국 충칭', 'qci.invest@qualatw.com', '중견기업'),
  ('G-2367', '충전컴퍼니', '03-1546851', '중국 상하이', 'energy11@ener.com', '중소기업'),
  ('G-6803', '토끼컴퍼니', '03-8465456', '중국 충칭', 'rabbit@rab.co.kr', '대기업'),
  ('H-9009', '전대공장', '055-260-1000', '대한민국 창원', 'abc1234@ssdelta.co.kr', '중견기업'),
  ('J-2144', '동아기술', '05-4542112', '일본 오사카', 'dongdong@aa.com', '대기업'),
  ('L-4543', '서울공장', '02-184-1451', '대한민국 서울', 'seoul0jang@jjan.com', '대기업'),
  ('P-4557', '메탈컴퍼니', '06-3777-111', '인도네시아 찌비뚱', 'lgelectronics@lge.com', '대기업'),
  ('Q-2434', '안전컴퍼니', '055-724-9401', '대한민국 김해', 'def5678@seilsa.com', '중소기업'),
  ('R-2034', '경기기술', '031-414-5115', '대한민국 오산', 'kyonggiuni@ver.com', '중소기업'),
  ('R-3231', '마루컴퍼니', '051-784-1254', '대한민국 부산', 'marucomp.fun.com', '대기업'),
  ('S-2002', '대진공업', '051-945-9999', '대한민국 부산', 'daejin0@add.com', '중견기업'),
  ('S-9002', '로얄컴퍼니', '051-222-3333', '대한민국 부산', 'royal3333@panny.com', '중견기업'),
  ('V-1761', '광안리기술', '051-232-5655', '대한민국 부산', 'gwong@add.com', '대기업'),
  ('W-3423', '최고컴퍼니', '031-454-5544', '대한민국 화성', 'verygooood@ver.com', '중소기업'),
  ('W-7634', '하루컴퍼니', '031-485-5555', '대한민국 용인', 'haruharu55@jjan.com', '중견기업');

-- product: 30건
INSERT INTO product (model_name, product_name, category, release_ym, price) VALUES
  ('14ZD90S-GX59K', 'LG 그램 35.5cm 인텔® 코어™ Ultra 5', '노트북', '2024-01', 1578830),
  ('15Z90S-GA59K', 'LG 그램 39.6cm 인텔® 코어™ Ultra 5', '노트북', '2024-01', 1729760),
  ('15ZD90S-GX79K', 'LG 그램 39.6cm 인텔® 코어™ Ultra 7', '노트북', '2024-01', 1835720),
  ('16T90SP-KA5BK', 'LG 그램 Pro 360 40.6cm 인텔® 코어™ Ultra 5', '노트북', '2024-01', 2190000),
  ('16T90SP-KD7BK', 'LG 그램 Pro 360 40.6cm 인텔® 코어™ Ultra 7', '노트북', '2024-01', 2740000),
  ('16Z90SP-KD7CK', 'LG 그램 Pro 40.6cm 인텔® 코어™ Ultra 7', '노트북', '2024-01', 2590000),
  ('16ZD90SP-EX59K', 'LG 그램 Pro 40.6cm 인텔® 코어™ Ultra 5', '노트북', '2024-01', 2213340),
  ('16ZD90SU-GX56K', 'LG 그램 40.6cm 인텔® 코어™ Ultra 5', '노트북', '2024-01', 1598000),
  ('16ZD90SU-GX76K', 'LG 그램 40.6cm 인텔® 코어™ Ultra 7', '노트북', '2024-01', 1848000),
  ('17Z90SP-EA5CK', 'LG 그램 Pro 43.1cm 인텔® 코어™ Ultra 5', '노트북', '2024-01', 2490000),
  ('17Z90SP-ED79K', 'LG 그램 Pro 43.1cm 인텔® 코어™ Ultra 7', '노트북', '2024-01', 2690000),
  ('17ZD90SU-GX56K', 'LG 그램 43.1cm 인텔® 코어™ Ultra 5', '노트북', '2024-01', 1650190),
  ('17ZD90SU-GX76K', 'LG 그램 43.1cm 인텔® 코어™ Ultra 7', '노트북', '2024-01', 1873310),
  ('43LM6350KNA', 'LG 일반 LED TV', 'TV', '2021-07', 590000),
  ('75QNED85TKA', 'LG QNED TV', 'TV', '2024-03', 3690000),
  ('75QNED91TKA', 'LG QNED evo', 'TV', '2024-03', 4290000),
  ('AS064PWBAR', 'LG 퓨리케어 오브제컬렉션 에어로퍼니처(원형)', '공기청정기', '2024-03', 665000),
  ('AS183HWWA', 'LG 퓨리케어 360˚ 공기청정기 Hit', '공기청정기', '2023-10', 659000),
  ('AS280DWFC', 'LG 퓨리케어 360˚ 공기청정기', '공기청정기', '2023-10', 1219000),
  ('AS283DWFA', 'LG 퓨리케어 360˚ 공기청정기 플러스', '공기청정기', '2023-12', 1219000),
  ('AS354NS3A', 'LG 퓨리케어 오브제컬렉션 360˚ 공기청정기 UV살균', '공기청정기', '2024-01', 2209000),
  ('FS064PSJA', 'LG 퓨리케어 오브제컬렉션 에어로타워 UV살균', '공기청정기', '2024-03', 1487000),
  ('HW100BVB', 'LG 퓨리케어 자연기화 가습기', '가습기', '2024-01', 389000),
  ('HW300BBN', 'LG 퓨리케어 에어워셔 자연식 가습기', '가습기', '2024-02', 224000),
  ('HY650RCAAH', 'LG 퓨리케어 오브제컬렉션 하이드로타워', '가습기', '2024-04', 1238000),
  ('OLED48B4NNA', 'LG 올레드 TV B4', 'TV', '2024-03', 1290000),
  ('OLED48C4KNA', 'LG 올레드 evo C4', 'TV', '2024-03', 2190000),
  ('S3MFC', 'LG 스타일러', '의류관리기', '2021-03', 1290000),
  ('S5BBPU', 'LG 스타일러 오브제 컬렉션', '의류관리기', '2022-09', 1690000),
  ('SC5GMR52', 'LG 스타일러 오브제 컬렉션 (ALL NEW)', '의류관리기', '2024-04', 2340000);

-- customer: 50건
INSERT INTO customer (customer_id, name, phone, address, birth_date, job) VALUES
  ('1002', '김정우', '010-8448-5511', '안성시', '1992-05-05', '회사원'),
  ('1111', '최우식', '010-6000-5111', '아산시', '1991-02-01', '주부'),
  ('1256', '조은석', '010-8545-1111', '통영시', '2001-01-14', '학생'),
  ('1425', '구지성', '010-6565-5555', '창원시', '2000-09-14', '학생'),
  ('1455', '김승민', '010-0922-0922', '밀양시', '2000-09-22', '학생'),
  ('1764', '허교란', '010-3721-0726', '과천시', '1977-07-26', '주부'),
  ('1865', '구조현', '010-6852-4452', '서울시', '1981-11-07', '주부'),
  ('2222', '김지민', '010-0404-4545', '광명시', '2002-11-07', '학생'),
  ('2281', '주이련', '010-6583-6335', '밀양시', '1980-06-25', '주부'),
  ('2565', '김민정', '010-1111-0101', '과천시', '1985-05-18', '주부'),
  ('2566', '박공학', '010-7867-1625', '서울시', '1978-09-27', '주부'),
  ('2816', '원이정', '010-1741-0669', '통영시', '2002-01-24', '학생'),
  ('3111', '김소희', '010-2200-2222', '통영시', '2004-06-29', '학생'),
  ('3262', '최원빈', '010-7454-5454', '강릉시', '1994-06-01', '회사원'),
  ('3282', '공여준', '010-0416-8378', '서울시', '1989-11-21', '주부'),
  ('3462', '안나은', '010-4857-2136', '진주시', '2003-05-16', '학생'),
  ('3554', '송혜교', '010-1122-1111', '김해시', '1988-10-23', '회사원'),
  ('3562', '서시효', '010-8490-9551', '수원시', '1973-04-18', '주부'),
  ('3578', '최경영', '010-5678-1234', '수원시', '1997-03-08', '회사원'),
  ('3762', '나규한', '010-9790-3586', '김해시', '1973-03-14', '주부'),
  ('3824', '배민하', '010-9691-4080', '서울시', '1988-04-14', '주부'),
  ('4144', '이지훈', '010-6554-1113', '창원시', '2004-01-02', '학생'),
  ('4215', '김선재', '010-2002-2023', '안성시', '1994-12-22', '회사원'),
  ('4550', '김태희', '010-1244-1544', '서울시', '1998-04-21', '회사원'),
  ('4567', '김산업', '010-1234-5678', '수원시', '2003-01-01', '학생'),
  ('4666', '류준열', '010-2777-5000', '청주시', '2001-01-17', '학생'),
  ('4789', '김정보', '010-3412-7835', '용인시', '2004-05-29', '학생'),
  ('4823', '노진리', '010-9449-2551', '수원시', '2001-08-08', '학생'),
  ('5000', '한도영', '010-4516-2000', '과명시', '1979-05-12', '주부'),
  ('5466', '이민서', '010-5161-7777', '서울시', '1974-06-22', '주부'),
  ('5656', '김지원', '010-7884-4455', '용인시', '1999-02-02', '학생'),
  ('6423', '박인혁', '010-8745-6665', '화성시', '1987-06-30', '회사원'),
  ('6444', '한소희', '010-8477-5666', '화성시', '2000-12-14', '학생'),
  ('6559', '김선비', '010-4561-1111', '화성시', '1976-11-17', '회사원'),
  ('6875', '이지은', '010-5555-1616', '김해시', '1998-01-01', '회사원'),
  ('7000', '이태일', '010-6221-0040', '과천시', '1998-12-10', '회사원'),
  ('7138', '은준주', '010-7498-5160', '김해시', '2002-07-12', '학생'),
  ('7224', '하영신', '010-8436-6961', '진주시', '1973-05-25', '주부'),
  ('7545', '이현진', '010-4520-4444', '서울시', '2000-05-11', '학생'),
  ('7618', '양슬민', '010-2937-4299', '서울시', '1980-04-06', '주부'),
  ('7647', '전기승', '010-7822-7386', '서울시', '1988-11-26', '주부'),
  ('7828', '곽수련', '010-3538-6032', '화성시', '2002-11-24', '학생'),
  ('7849', '강민철', '010-4578-3212', '진주시', '2005-12-04', '학생'),
  ('7877', '변우석', '010-7744-7777', '밀양시', '1994-12-05', '회사원'),
  ('7925', '진수혜', '010-3836-0975', '화성시', '2001-03-18', '학생'),
  ('8405', '임소라', '010-8877-8877', '충주시', '1986-08-15', '주부'),
  ('8544', '김수현', '010-5648-2333', '수원시', '1997-03-01', '회사원'),
  ('8911', '노효채', '010-6663-6411', '용인시', '2002-04-15', '학생'),
  ('9898', '이민호', '010-1025-1025', '김포시', '1998-10-25', '회사원'),
  ('9989', '아무개', '010-4567-7896', '남양주시', '2002-09-12', '학생');

-- manufacture: 154건
INSERT INTO manufacture (serial_no, model_name, mfg_date, unit_cost, is_defective, mfg_manager, biz_no) VALUES
  ('AIR241333', 'FS064PSJA', '2024-03-08', 1200000, 0, '남휘연', 'G-1004'),
  ('AIR241335', 'AS064PWBAR', '2024-03-08', 600000, 0, '배상미', 'C-6532'),
  ('AIR241336', 'AS064PWBAR', '2024-03-08', 600000, 0, '윤병성', 'C-6766'),
  ('AIR241337', 'AS064PWBAR', '2024-03-08', 600000, 0, '정세현', 'C-9833'),
  ('AIR241338', 'AS064PWBAR', '2024-03-08', 600000, 0, '추이언', 'H-9009'),
  ('AIR241339', 'AS064PWBAR', '2024-03-08', 600000, 0, '곽철용', 'S-2002'),
  ('AIR241340', 'AS183HWWA', '2023-10-08', 600000, 0, '황성선', 'A-3222'),
  ('AIR241341', 'AS183HWWA', '2023-10-08', 600000, 0, '엄진진', 'C-0935'),
  ('AIR241342', 'AS183HWWA', '2023-10-08', 600000, 0, '최송서', 'D-6335'),
  ('AIR241343', 'AS183HWWA', '2023-10-08', 600000, 1, '임송비', 'F-1323'),
  ('AIR241344', 'AS183HWWA', '2023-10-08', 600000, 0, '최덕복', 'W-7634'),
  ('AIR241346', 'AS354NS3A', '2024-01-08', 1900000, 0, '김여인', 'B-1445'),
  ('AIR241347', 'AS354NS3A', '2024-01-08', 1900000, 0, '장병래', 'G-6803'),
  ('AIR241348', 'AS354NS3A', '2024-01-08', 1900000, 0, '조채우', 'L-4543'),
  ('AIR241349', 'AS354NS3A', '2024-01-08', 1900000, 0, '윤하민', 'Q-2434'),
  ('AIR241350', 'AS354NS3A', '2024-01-08', 1900000, 1, '강송선', 'W-7634'),
  ('AIR241351', 'AS354NS3A', '2024-01-08', 1900000, 0, '구조수', 'D-6335'),
  ('AIR241352', 'AS354NS3A', '2024-01-08', 1900000, 0, '구유현', 'R-3231'),
  ('AIR241353', 'FS064PSJA', '2024-01-08', 1900000, 0, '송비나', 'S-2002'),
  ('AIR241356', 'AS280DWFC', '2023-10-08', 1000000, 0, '안시한', 'B-4022'),
  ('AIR241357', 'AS280DWFC', '2023-10-08', 1000000, 0, '엄준세', 'C-0935'),
  ('AIR241358', 'AS280DWFC', '2023-10-08', 1000000, 0, '송예름', 'D-7555'),
  ('AIR241359', 'AS280DWFC', '2023-10-08', 1000000, 0, '엄석용', 'F-1323'),
  ('AIR241360', 'AS280DWFC', '2023-10-08', 1000000, 0, '나현영', 'F-4223'),
  ('AIR241361', 'AS283DWFA', '2023-10-08', 1000000, 0, '김미선', 'B-1223'),
  ('AIR241362', 'AS283DWFA', '2023-10-08', 1000000, 0, '여은성', 'D-7555'),
  ('AIR241363', 'AS283DWFA', '2023-10-08', 1000000, 1, '표가선', 'G-2367'),
  ('AIR241364', 'AS283DWFA', '2023-10-08', 1200000, 0, '우다온', 'R-3231'),
  ('AIR241365', 'AS283DWFA', '2023-10-08', 1000000, 0, '도영기', 'S-2002'),
  ('AIR241380', 'FS064PSJA', '2024-01-08', 1900000, 0, '양병안', 'D-1212'),
  ('AIR241381', 'FS064PSJA', '2024-01-08', 1900000, 0, '편승예', 'F-2364'),
  ('AIR241382', 'FS064PSJA', '2024-01-08', 1900000, 0, '류해효', 'G-2367'),
  ('AIR241605', 'AS283DWFA', '2023-12-08', 1200000, 0, '강주덕', 'C-0935'),
  ('AIR241606', 'AS283DWFA', '2023-12-08', 1200000, 0, '편하승', 'G-6803'),
  ('AIR241607', 'AS283DWFA', '2023-12-08', 1200000, 1, '김근철', 'P-4557'),
  ('HUMID1016', 'HY650RCAAH', '2024-04-08', 1040000, 0, '공소령', 'W-3423'),
  ('HUMID1043', 'HY650RCAAH', '2024-04-08', 1040000, 0, '박주휘', 'J-2144'),
  ('HUMID1077', 'HY650RCAAH', '2024-04-08', 1040000, 1, '곽해빈', 'C-6532'),
  ('HUMID1099', 'HY650RCAAH', '2024-04-08', 1040000, 0, '여승욱', 'D-6335'),
  ('HUMID1143', 'HY650RCAAH', '2024-04-08', 1040000, 0, '석민지', 'R-2034'),
  ('HUMID1156', 'HW100BVB', '2024-01-08', 310000, 0, '하채성', 'A-1221'),
  ('HUMID1157', 'HW100BVB', '2024-01-08', 310000, 0, '안고혜', 'B-4022'),
  ('HUMID1158', 'HW100BVB', '2024-01-08', 310000, 1, '배비름', 'D-7555'),
  ('HUMID1159', 'HW100BVB', '2024-01-08', 310000, 0, '전의승', 'E-1232'),
  ('HUMID1160', 'HW100BVB', '2024-01-08', 310000, 0, '나윤옥', 'E-1232'),
  ('HUMID1161', 'HW100BVB', '2024-01-08', 310000, 0, '공양준', 'F-1222'),
  ('HUMID1162', 'HW100BVB', '2024-01-08', 310000, 0, '최상나', 'F-4223'),
  ('HUMID1163', 'HW100BVB', '2024-01-08', 310000, 0, '추조아', 'G-1004'),
  ('HUMID1164', 'HW100BVB', '2024-01-08', 310000, 1, '류비연', 'G-1004'),
  ('HUMID1165', 'HW100BVB', '2024-01-08', 310000, 0, '공솔연', 'G-2367'),
  ('HUMID1166', 'HW100BVB', '2024-01-08', 310000, 0, '강진성', 'H-9009'),
  ('HUMID1167', 'HW100BVB', '2024-01-08', 310000, 1, '염서원', 'V-1761'),
  ('HUMID1168', 'HW100BVB', '2024-01-08', 310000, 0, '민도름', 'W-3423'),
  ('HUMID1198', 'HY650RCAAH', '2024-04-08', 1040000, 0, '송김한', 'H-9009'),
  ('HUMID1211', 'HY650RCAAH', '2024-04-08', 1040000, 0, '황하정', 'E-1232'),
  ('HUMID1212', 'HY650RCAAH', '2024-04-08', 1040000, 0, '홍채소', 'F-4223'),
  ('HUMID1277', 'HY650RCAAH', '2024-04-08', 1040000, 0, '지수솔', 'W-3423'),
  ('HUMID1279', 'HY650RCAAH', '2024-04-08', 1040000, 1, '석윤이', 'F-1222'),
  ('HUMID1280', 'HW300BBN', '2024-01-08', 185000, 0, '곽우령', 'J-2144'),
  ('HUMID1281', 'HW300BBN', '2024-01-08', 185000, 0, '신명유', 'S-9002'),
  ('HUMID1282', 'HW300BBN', '2024-01-08', 185000, 0, '변기인', 'V-1761'),
  ('HUMID1283', 'HW300BBN', '2024-02-08', 185000, 0, '황원경', 'A-1221'),
  ('HUMID1284', 'HW300BBN', '2024-02-08', 185000, 0, '진주빈', 'B-4022'),
  ('HUMID1285', 'HW300BBN', '2024-02-08', 185000, 0, '허태완', 'F-1323'),
  ('HUMID1286', 'HW300BBN', '2024-02-08', 185000, 0, '임김한', 'G-6803'),
  ('HUMID1287', 'HW300BBN', '2024-02-08', 185000, 1, '여다화', 'L-4543'),
  ('HUMID1288', 'HW300BBN', '2024-02-08', 185000, 0, '양은비', 'P-4557'),
  ('HUMID1289', 'HW300BBN', '2024-02-08', 185000, 0, '배소완', 'S-2002'),
  ('STYLER1020', 'SC5GMR52', '2024-04-08', 2245000, 0, '류순리', 'A-3222'),
  ('STYLER1021', 'SC5GMR52', '2024-04-08', 2245000, 0, '오소욱', 'B-1223'),
  ('STYLER1022', 'SC5GMR52', '2024-04-08', 2245000, 0, '최효효', 'B-1445'),
  ('STYLER1023', 'SC5GMR52', '2024-04-08', 2245000, 0, '조우당', 'B-4022'),
  ('STYLER1024', 'SC5GMR52', '2024-04-08', 2245000, 1, '여지당', 'C-6532'),
  ('STYLER1025', 'SC5GMR52', '2024-04-08', 2245000, 0, '남규율', 'C-6766'),
  ('STYLER1026', 'SC5GMR52', '2024-04-08', 2245000, 0, '강한미', 'F-1222'),
  ('STYLER1027', 'SC5GMR52', '2024-04-08', 2245000, 0, '원휘향', 'F-2364'),
  ('STYLER1028', 'SC5GMR52', '2024-04-08', 2245000, 0, '주연이', 'J-2144'),
  ('STYLER1029', 'SC5GMR52', '2024-04-08', 2245000, 0, '백성아', 'P-4557'),
  ('STYLER1030', 'SC5GMR52', '2024-04-08', 2245000, 0, '전의옥', 'S-9002'),
  ('STYLER1031', 'SC5GMR52', '2024-04-08', 2245000, 0, '윤의율', 'V-1761'),
  ('STYLER1032', 'SC5GMR52', '2024-04-08', 2245000, 0, '공근옥', 'W-7634'),
  ('STYLER1110', 'S3MFC', '2021-03-08', 1040000, 0, '이희인', 'D-7555'),
  ('STYLER1111', 'S3MFC', '2021-03-08', 1040000, 0, '문세림', 'A-3222'),
  ('STYLER1112', 'S3MFC', '2021-03-08', 1040000, 0, '진민수', 'B-1445'),
  ('STYLER1113', 'S3MFC', '2021-03-08', 1040000, 0, '윤세리', 'C-9833'),
  ('STYLER1114', 'S3MFC', '2021-03-08', 1040000, 1, '김진교', 'C-9833'),
  ('STYLER1115', 'S3MFC', '2021-03-08', 1040000, 0, '임서연', 'D-1212'),
  ('STYLER1116', 'S3MFC', '2021-03-08', 1040000, 0, '손세연', 'F-2364'),
  ('STYLER1117', 'S3MFC', '2021-03-08', 1432000, 0, '추초진', 'F-4223'),
  ('STYLER1118', 'S3MFC', '2021-03-08', 1090000, 0, '안수림', 'G-2367'),
  ('STYLER1119', 'S3MFC', '2021-03-08', 1040000, 0, '나예소', 'S-9002'),
  ('STYLER1139', 'S5BBPU', '2022-09-08', 1390000, 0, '홍채령', 'C-6766'),
  ('STYLER1140', 'S5BBPU', '2022-09-08', 1876000, 0, '곽유준', 'D-1212'),
  ('STYLER1141', 'S5BBPU', '2022-09-08', 1440000, 0, '나도서', 'Q-2434'),
  ('STYLER1142', 'S5BBPU', '2022-09-08', 1440000, 0, '엄고향', 'R-3231'),
  ('STYLER1384', 'S3MFC', '2021-08-08', 1040000, 0, '장의민', 'C-0935'),
  ('STYLER1385', 'S3MFC', '2021-11-08', 1040000, 0, '정유재', 'R-2034'),
  ('TVLE0001', '43LM6350KNA', '2021-07-08', 450000, 0, '도송하', 'D-1212'),
  ('TVLE0002', '43LM6350KNA', '2021-07-08', 450000, 1, '조정미', 'H-9009'),
  ('TVOC0001', 'OLED48C4KNA', '2024-03-08', 1750000, 0, '허유한', 'V-1761'),
  ('TVOC0002', 'OLED48C4KNA', '2024-03-08', 1750000, 0, '은기린', 'F-1222'),
  ('TVOC0003', 'OLED48C4KNA', '2024-03-08', 1750000, 1, '변원당', 'R-2034'),
  ('TVOC0004', 'OLED48C4KNA', '2024-03-08', 1750000, 0, '공혜혜', 'G-1004'),
  ('TVOC0005', 'OLED48C4KNA', '2024-03-08', 1750000, 0, '권여영', 'F-2364'),
  ('TVOC0006', 'OLED48C4KNA', '2024-03-08', 1750000, 1, '류재수', 'A-3222'),
  ('TVOL0001', 'OLED48B4NNA', '2024-03-08', 1000000, 0, '민지래', 'Q-2434'),
  ('TVOL0002', 'OLED48B4NNA', '2024-03-08', 1000000, 0, '여우솔', 'A-1221'),
  ('TVOL0003', 'OLED48B4NNA', '2024-03-08', 1000000, 0, '권승우', 'L-4543'),
  ('TVOL0004', 'OLED48B4NNA', '2024-03-08', 1000000, 0, '권지이', 'J-2144'),
  ('TVQE0001', '75QNED85TKA', '2024-03-08', 3000000, 0, '염정효', 'C-9833'),
  ('TVQE0002', '75QNED85TKA', '2024-03-08', 3000000, 0, '우서령', 'C-6532'),
  ('TVQE0003', '75QNED85TKA', '2024-03-08', 3000000, 0, '구솔옥', 'R-2034'),
  ('TVQE0004', '75QNED85TKA', '2024-03-08', 3000000, 0, '노교세', 'Q-2434'),
  ('TVQV0001', '75QNED91TKA', '2024-03-08', 3900000, 0, '은솔지', 'L-4543'),
  ('TVQV0002', '75QNED91TKA', '2024-03-08', 3900000, 1, '양순민', 'B-1223'),
  ('U5140002', '14ZD90S-GX59K', '2024-01-08', 1200000, 0, '엄재재', 'E-1232'),
  ('U5140003', '14ZD90S-GX59K', '2024-01-08', 1200000, 0, '엄재재', 'E-1232'),
  ('U5140004', '14ZD90S-GX59K', '2024-01-08', 1200000, 0, '엄재재', 'E-1232'),
  ('U5140005', '14ZD90S-GX59K', '2024-01-08', 1200000, 0, '엄재재', 'E-1232'),
  ('U5140006', '14ZD90S-GX59K', '2024-01-08', 1200000, 0, '엄재재', 'E-1232'),
  ('U5140007', '14ZD90S-GX59K', '2024-01-08', 1200000, 0, '엄재재', 'E-1232'),
  ('U5150001', '15Z90S-GA59K', '2024-01-08', 1200000, 0, '백비향', 'D-6335'),
  ('U5150002', '15Z90S-GA59K', '2024-01-08', 1200000, 1, '고시수', 'F-1323'),
  ('U5150003', '15Z90S-GA59K', '2024-01-08', 1200000, 0, '권도승', 'W-7634'),
  ('U5160001', '16ZD90SU-GX56K', '2024-01-08', 1300000, 0, '황의채', 'C-6766'),
  ('U516PR0001', '16ZD90SP-EX59K', '2024-01-08', 1700000, 0, '장채소', 'G-6803'),
  ('U516PR0002', '16ZD90SP-EX59K', '2024-01-08', 1700000, 0, '우세화', 'B-1223'),
  ('U5170001', '17ZD90SU-GX56K', '2024-01-08', 1250000, 0, '배가기', 'R-3231'),
  ('U5170002', '17ZD90SU-GX56K', '2024-01-08', 1250000, 0, '도경율', 'A-1221'),
  ('U5170003', '17ZD90SU-GX56K', '2024-01-08', 1250000, 0, '배승휘', 'S-9002'),
  ('U5170004', '17ZD90SU-GX56K', '2024-01-08', 1250000, 0, '표병호', 'F-1323'),
  ('U517PR0001', '17Z90SP-EA5CK', '2024-01-08', 2100000, 0, '유병혜', 'F-4223'),
  ('U7150001', '15ZD90S-GX79K', '2024-01-08', 1600000, 1, '노지영', 'C-0935'),
  ('U7150002', '15ZD90S-GX79K', '2024-01-08', 1600000, 0, '양상한', 'W-3423'),
  ('U7150003', '15ZD90S-GX79K', '2024-01-08', 1600000, 0, '하김유', 'S-2002'),
  ('U7150004', '15ZD90S-GX79K', '2024-01-08', 1600000, 0, '염휘유', 'F-1222'),
  ('U7160001', '16ZD90SU-GX76K', '2024-01-08', 1500000, 0, '방가효', 'A-1221'),
  ('U7160002', '16ZD90SU-GX76K', '2024-01-08', 1500000, 0, '한선린', 'C-6766'),
  ('U7160003', '16ZD90SU-GX76K', '2024-01-08', 1500000, 1, '원휘예', 'W-7634'),
  ('U7160004', '16ZD90SU-GX76K', '2024-01-08', 1500000, 0, '차비재', 'F-2364'),
  ('U71636PR01', '16T90SP-KD7BK', '2024-01-08', 2300000, 1, '송효지', 'D-1212'),
  ('U71636PR02', '16T90SP-KD7BK', '2024-01-08', 2300000, 0, '최선영', 'R-2034'),
  ('U71636PR03', '16T90SP-KD7BK', '2024-01-08', 2300000, 0, '문성련', 'R-3231'),
  ('U71636PR04', '16T90SP-KD7BK', '2024-01-08', 2300000, 0, '원여소', 'A-3222'),
  ('U71636PR05', '16T90SP-KA5BK', '2024-01-08', 1750000, 0, '엄송이', 'V-1761'),
  ('U71636PR06', '16T90SP-KA5BK', '2024-01-08', 1750000, 0, '편하안', 'B-1223'),
  ('U71636PR07', '16T90SP-KA5BK', '2024-01-08', 1750000, 0, '신우율', 'D-6335'),
  ('U71636PR08', '16T90SP-KA5BK', '2024-01-08', 1750000, 0, '은상송', 'L-4543'),
  ('U716PR0001', '16Z90SP-KD7CK', '2024-01-08', 2100000, 0, '유근란', 'S-9002'),
  ('U716PR0002', '16Z90SP-KD7CK', '2024-01-08', 2100000, 0, '곽도인', 'Q-2434'),
  ('U716PR0003', '16Z90SP-KD7CK', '2024-01-08', 2100000, 0, '변양안', 'G-6803'),
  ('U7170001', '17ZD90SU-GX76K', '2024-01-08', 1500000, 0, '추김련', 'H-9009'),
  ('U7170002', '17ZD90SU-GX76K', '2024-01-08', 1500000, 0, '탁시래', 'E-1232'),
  ('U717PR0001', '17Z90SP-ED79K', '2024-01-08', 2390000, 0, '한한림', 'B-4022');

-- orders: 36건
INSERT INTO orders (serial_no, customer_id, model_name, order_date, payment_method) VALUES
  ('AIR241338', '7849', 'AS064PWBAR', '2024-03-31', '신용카드'),
  ('AIR241339', '6423', 'AS064PWBAR', '2024-03-31', '신용카드'),
  ('AIR241342', '7925', 'AS183HWWA', '2024-04-10', '체크카드'),
  ('AIR241343', '5000', 'AS183HWWA', '2024-04-04', '체크카드'),
  ('AIR241344', '3824', 'AS183HWWA', '2024-04-01', '체크카드'),
  ('AIR241356', '3762', 'AS280DWFC', '2024-04-07', '신용카드'),
  ('AIR241361', '2566', 'AS283DWFA', '2024-04-10', '신용카드'),
  ('AIR241362', '4550', 'AS283DWFA', '2024-03-28', '신용카드'),
  ('HUMID1162', '2565', 'HW100BVB', '2024-01-09', '체크카드'),
  ('HUMID1280', '8911', 'HW300BBN', '2024-02-05', '신용카드'),
  ('HUMID1281', '1865', 'HW300BBN', '2024-02-13', '신용카드'),
  ('HUMID1282', '4215', 'HW300BBN', '2024-02-07', '신용카드'),
  ('STYLER1139', '3554', 'S5BBPU', '2024-03-25', '신용카드'),
  ('STYLER1142', '1111', 'S5BBPU', '2024-02-01', '신용카드'),
  ('STYLER1384', '3578', 'S3MFC', '2024-05-03', '신용카드'),
  ('TVLE0002', '6559', '43LM6350KNA', '2024-03-07', '신용카드'),
  ('TVOL0004', '1764', 'OLED48B4NNA', '2024-04-02', '체크카드'),
  ('TVQE0002', '8405', '75QNED85TKA', '2024-04-17', '신용카드'),
  ('TVQE0004', '7618', '75QNED85TKA', '2024-04-20', '신용카드'),
  ('TVQV0002', '5466', '75QNED91TKA', '2024-04-20', '신용카드'),
  ('U5140002', '2816', '14ZD90S-GX59K', '2024-02-13', '신용카드'),
  ('U5140003', '3111', '14ZD90S-GX59K', '2024-02-13', '신용카드'),
  ('U5140004', '3462', '14ZD90S-GX59K', '2024-02-21', '체크카드'),
  ('U5140005', '2222', '14ZD90S-GX59K', '2024-02-12', '신용카드'),
  ('U5140006', '4144', '14ZD90S-GX59K', '2024-03-02', '신용카드'),
  ('U5140007', '4567', '14ZD90S-GX59K', '2024-02-18', '신용카드'),
  ('U5150001', '4666', '15Z90S-GA59K', '2024-02-25', '신용카드'),
  ('U5170002', '6444', '17ZD90SU-GX56K', '2024-02-27', '신용카드'),
  ('U5170003', '4823', '17ZD90SU-GX56K', '2024-03-04', '신용카드'),
  ('U5170004', '5656', '17ZD90SU-GX56K', '2024-02-14', '체크카드'),
  ('U7150001', '4789', '15ZD90S-GX79K', '2024-02-15', '신용카드'),
  ('U716PR0002', '7000', '16Z90SP-KD7CK', '2024-01-31', '신용카드'),
  ('U716PR0003', '7877', '16Z90SP-KD7CK', '2024-02-24', '신용카드'),
  ('U7170001', '7545', '17ZD90SU-GX76K', '2024-02-21', '신용카드'),
  ('U7170002', '7138', '17ZD90SU-GX76K', '2024-02-24', '신용카드'),
  ('U717PR0001', '6875', '17Z90SP-ED79K', '2024-04-07', '신용카드');


-- =====================================================================
-- [STEP 3] 적재 검증 : 원본 데이터와 숫자가 같아야 정상
-- =====================================================================

-- 3-1. 테이블별 건수 (원본 데이터 행 수: 제조사 32, 상품 30, 고객 50, 제조 154, 주문 36)
SELECT 'manufacturer' AS tbl, COUNT(*) AS n, 32 AS expected FROM manufacturer
UNION ALL SELECT 'product',     COUNT(*),  30 FROM product
UNION ALL SELECT 'customer',    COUNT(*),  50 FROM customer
UNION ALL SELECT 'manufacture', COUNT(*), 154 FROM manufacture
UNION ALL SELECT 'orders',      COUNT(*),  36 FROM orders;

-- 3-2. 날짜가 깨지지 않았는지 (0000-00-00, 1970 등이 나오면 변환 실패)
SELECT 'orders.order_date' AS col, MIN(order_date) AS min_v, MAX(order_date) AS max_v FROM orders
UNION ALL SELECT 'manufacture.mfg_date', MIN(mfg_date), MAX(mfg_date) FROM manufacture
UNION ALL SELECT 'customer.birth_date',  MIN(birth_date), MAX(birth_date) FROM customer;

-- 3-3. 불량여부가 0/1만 있는지
SELECT is_defective, COUNT(*) AS n FROM manufacture GROUP BY is_defective;

-- 3-4. 주문의 모델명과 제조 이력의 모델명이 일치하는지 (0건이어야 정상)
SELECT o.serial_no, o.model_name AS order_model, m.model_name AS mfg_model
FROM orders o
JOIN manufacture m ON m.serial_no = o.serial_no
WHERE o.model_name <> m.model_name;


-- =====================================================================
-- [STEP 4] 데이터 품질 점검 : 규칙에 어긋나는 예외 케이스 찾기
-- =====================================================================

-- 4-1. 출시 전에 주문된 건 (주문월 < 출시월)
SELECT o.serial_no, o.model_name, o.order_date, p.release_ym
FROM orders o
JOIN product p ON p.model_name = o.model_name
WHERE DATE_FORMAT(o.order_date, '%Y-%m') < p.release_ym;

-- 4-2. 불량 판정된 제품이 판매된 건
SELECT o.serial_no, o.model_name, o.order_date, c.name AS customer
FROM orders o
JOIN manufacture m ON m.serial_no   = o.serial_no
JOIN customer    c ON c.customer_id = o.customer_id
WHERE m.is_defective = 1;

-- 4-3. 제조단가가 판매가 이상인 건 (역마진)
SELECT m.serial_no, m.model_name, m.unit_cost, p.price
FROM manufacture m
JOIN product p ON p.model_name = m.model_name
WHERE m.unit_cost >= p.price;

-- 4-4. 같은 모델인데 제조단가가 여러 개인 경우 (단가 기준 불일치)
SELECT model_name,
       COUNT(DISTINCT unit_cost) AS n_cost_levels,
       MIN(unit_cost) AS min_cost,
       MAX(unit_cost) AS max_cost
FROM manufacture
GROUP BY model_name
HAVING COUNT(DISTINCT unit_cost) > 1;

-- 4-5. 형식 오류 : 이메일에 '@' 없음, 전화번호 형식 불일치
SELECT biz_no, company_name, email, phone,
       CASE WHEN email NOT LIKE '%@%' THEN 'email_no_at' END AS email_issue,
       CASE WHEN phone NOT REGEXP '^0[0-9]{1,2}-[0-9]{3,4}-[0-9]{4}$' THEN 'phone_format' END AS phone_issue
FROM manufacturer
WHERE email NOT LIKE '%@%'
   OR phone NOT REGEXP '^0[0-9]{1,2}-[0-9]{3,4}-[0-9]{4}$';


-- =====================================================================
-- [STEP 5] 요구조건별 쿼리 15개
--   작성 방식
--     테이블 연결은 JOIN ... ON 으로 조인 조건을 명시
--     검색 조건은 아래 SET @변수 에서 한 번에 지정 (값만 바꿔서 재실행)
--     부분 일치 검색은 LIKE CONCAT('%', @변수, '%')
--     불량 여부는 is_defective = 1 로 판단
--     다른 쿼리 결과를 재사용할 때는 CTE
-- =====================================================================

-- 매개변수 값 (여기만 바꾸면 아래 검색 쿼리 결과가 바뀝니다)
SET @customer_id   := '4567';        -- 1
SET @country       := '중국';         -- 4
SET @company_kw    := '컴퍼니';       -- 5
SET @order_date    := '2024-04-20';  -- 6
SET @customer_name := '김산업';       -- 7, 14
SET @company       := '번개공장';     -- 11

-- 1. (고객) 고객번호로 배송지 검색
SELECT c.name, c.address AS ship_to
FROM customer c
WHERE c.customer_id = @customer_id;

-- 2. (제조) 모델별 불량 개수
SELECT p.product_name, m.model_name, COUNT(*) AS defect_cnt
FROM manufacture m
JOIN product p ON p.model_name = m.model_name
WHERE m.is_defective = 1
GROUP BY p.product_name, m.model_name
ORDER BY defect_cnt DESC;

-- 3. (제조) 불량만 보기
SELECT *
FROM manufacture
WHERE is_defective = 1;

-- 4. (제조사) 국가/지역 검색
SELECT company_name, biz_no, address
FROM manufacturer
WHERE address LIKE CONCAT('%', @country, '%');

-- 5. (제조사) 연락처 검색
SELECT company_name, email, phone
FROM manufacturer
WHERE company_name LIKE CONCAT('%', @company_kw, '%');

-- 6. (주문) 날짜별 주문내역 / 송장
SELECT o.order_date, c.name, c.address AS ship_to, p.model_name, p.price
FROM orders o
JOIN customer c ON c.customer_id = o.customer_id
JOIN product  p ON p.model_name  = o.model_name
WHERE o.order_date = @order_date;

-- 7. (주문) 특정 고객 주문내역
SELECT p.product_name, o.model_name, o.order_date, o.payment_method
FROM customer c
JOIN orders  o ON o.customer_id = c.customer_id
JOIN product p ON p.model_name  = o.model_name
WHERE c.name = @customer_name
ORDER BY o.order_date;

-- 8. 상품별 제조량
SELECT m.model_name, p.product_name, COUNT(*) AS mfg_qty
FROM manufacture m
JOIN product p ON p.model_name = m.model_name
GROUP BY m.model_name, p.product_name
ORDER BY mfg_qty DESC;

-- 9. 상품별 주문량
SELECT o.model_name, p.product_name, COUNT(*) AS order_qty
FROM orders o
JOIN product p ON p.model_name = o.model_name
GROUP BY o.model_name, p.product_name
ORDER BY order_qty DESC;

-- 10. 상품별 판매량 / 매출액
SELECT p.model_name, p.product_name,
       COUNT(*)     AS sales_qty,
       SUM(p.price) AS revenue
FROM orders o
JOIN product p ON p.model_name = o.model_name
GROUP BY p.model_name, p.product_name
ORDER BY revenue DESC;

-- 11. 제조 유통 관리 : 특정 제조사가 만든 모델
SELECT mf.company_name, m.model_name
FROM manufacture m
JOIN manufacturer mf ON mf.biz_no = m.biz_no
WHERE mf.company_name = @company;

-- 12. 제조사별 생산건수 / 예상 매출액
-- 12-A. 기존 쿼리 (주의: 결과가 부풀려짐)
--   제조와 주문을 '모델명'으로 조인하면, 같은 모델의 제조 N대 x 주문 M건이
--   모두 짝지어져 N x M 행이 생깁니다. 생산건수와 매출액이 실제보다 커집니다.
SELECT mf.company_name,
       COUNT(m.model_name) AS mfg_cnt,
       SUM(p.price)        AS expected_revenue
FROM manufacture m
JOIN manufacturer mf ON mf.biz_no     = m.biz_no
JOIN product      p  ON p.model_name  = m.model_name
JOIN orders       o  ON o.model_name  = m.model_name
GROUP BY mf.company_name
ORDER BY expected_revenue DESC;

-- 12-B. 부풀림 확인 : 기존 조인 행 수 vs 실제 제조 대수
SELECT (SELECT COUNT(*)
          FROM manufacture m
          JOIN orders o ON o.model_name = m.model_name) AS joined_rows_original,
       (SELECT COUNT(*) FROM manufacture)               AS actual_mfg_units,
       (SELECT COUNT(*) FROM orders)                    AS actual_orders;

-- 12-C. 수정본 : 생산건수는 제조 기준, 매출은 '그 제조사가 만든 제품이 실제로 팔린 것'만
--   주문과 제조를 일련번호로 연결해 제품 1대 = 1행을 유지
SELECT mf.company_name,
       COUNT(*)                 AS mfg_cnt,
       COUNT(o.serial_no)       AS sold_cnt,
       COALESCE(SUM(CASE WHEN o.serial_no IS NOT NULL THEN p.price END), 0) AS actual_revenue,
       SUM(CASE WHEN m.is_defective = 0 THEN p.price ELSE 0 END)           AS potential_revenue
FROM manufacture m
JOIN manufacturer mf ON mf.biz_no    = m.biz_no
JOIN product      p  ON p.model_name = m.model_name
LEFT JOIN orders  o  ON o.serial_no  = m.serial_no
GROUP BY mf.company_name
ORDER BY actual_revenue DESC, potential_revenue DESC;

-- 13. 주문된 모델 수량
SELECT model_name, COUNT(*) AS qty
FROM orders
GROUP BY model_name
ORDER BY qty DESC;

-- 14. 직업별 상품 추천 (서브쿼리 + CASE)
--     개선본은 STEP 6-1 참고
SELECT category, product_name, model_name, price
FROM product
WHERE category = CASE (SELECT job FROM customer WHERE name = @customer_name)
                   WHEN '주부'   THEN '가습기'
                   WHEN '학생'   THEN '노트북'
                   WHEN '회사원' THEN '노트북'
                 END
  AND price   <= CASE (SELECT job FROM customer WHERE name = @customer_name)
                   WHEN '주부'   THEN 500000
                   WHEN '학생'   THEN 1800000
                   WHEN '회사원' THEN 2500000
                 END
ORDER BY price;

-- 15. 판매수요 관리 : 카테고리별 총 주문 수량
--     13번 결과(모델별 주문 수량)를 CTE로 재사용
WITH ordered_model_qty AS (
  SELECT model_name, COUNT(*) AS qty
  FROM orders
  GROUP BY model_name
)
SELECT p.category, SUM(q.qty) AS total_qty
FROM product p
JOIN ordered_model_qty q ON q.model_name = p.model_name
GROUP BY p.category
ORDER BY total_qty DESC;


-- =====================================================================
-- [STEP 6] CTE / 윈도우 함수 확장 분석
-- =====================================================================

-- 6-1. 요구조건 7 직업별 추천상품
--      기존 14번: 같은 서브쿼리를 조건마다 반복
--      개선: 대상 고객과 추천 규칙을 CTE로 분리 -> 규칙 변경 시 rule_map만 수정
WITH target AS (
  SELECT customer_id, name, job
  FROM customer
  WHERE name = @customer_name
),
rule_map AS (
  SELECT '주부' AS job, '가습기' AS category, 500000 AS max_price
  UNION ALL SELECT '학생',   '노트북', 1800000
  UNION ALL SELECT '회사원', '노트북', 2500000
)
SELECT t.name, t.job, p.category, p.product_name, p.model_name, p.price
FROM target t
JOIN rule_map r ON r.job = t.job
JOIN product  p ON p.category = r.category
               AND p.price   <= r.max_price
ORDER BY p.price;

-- 6-2. 월별 매출, 누적 매출, 전월 대비 증감 (SUM() OVER, LAG)
WITH monthly AS (
  SELECT DATE_FORMAT(o.order_date, '%Y-%m') AS ym,
         COUNT(*)     AS orders_cnt,
         SUM(p.price) AS revenue
  FROM orders o
  JOIN product p ON p.model_name = o.model_name
  GROUP BY DATE_FORMAT(o.order_date, '%Y-%m')
)
SELECT ym, orders_cnt, revenue,
       SUM(revenue) OVER (ORDER BY ym)            AS cum_revenue,
       revenue - LAG(revenue) OVER (ORDER BY ym)  AS mom_diff
FROM monthly
ORDER BY ym;

-- 6-3. 카테고리 내 모델별 매출 순위와 점유율 (RANK, PARTITION BY)
WITH model_rev AS (
  SELECT p.category, p.model_name, p.product_name,
         COUNT(*)     AS sales_qty,
         SUM(p.price) AS revenue
  FROM orders o
  JOIN product p ON p.model_name = o.model_name
  GROUP BY p.category, p.model_name, p.product_name
)
SELECT category, model_name, product_name, sales_qty, revenue,
       RANK() OVER (PARTITION BY category ORDER BY revenue DESC) AS rank_in_cat,
       ROUND(revenue / SUM(revenue) OVER (PARTITION BY category) * 100, 1) AS share_pct
FROM model_rev
ORDER BY category, rank_in_cat;

-- 6-4. 제조사별 불량률 순위 (신뢰 제조사 선별)
--      제조 3대 미만은 불량률이 과장되므로 별도 표시
WITH defect AS (
  SELECT mf.biz_no, mf.company_name,
         COUNT(*)            AS mfg_qty,
         SUM(m.is_defective) AS defect_qty
  FROM manufacture m
  JOIN manufacturer mf ON mf.biz_no = m.biz_no
  GROUP BY mf.biz_no, mf.company_name
)
SELECT company_name, mfg_qty, defect_qty,
       ROUND(defect_qty / mfg_qty * 100, 1) AS defect_rate_pct,
       DENSE_RANK() OVER (ORDER BY defect_qty / mfg_qty DESC) AS risk_rank,
       CASE WHEN mfg_qty < 3 THEN '표본 부족' ELSE '' END AS note
FROM defect
ORDER BY risk_rank, mfg_qty DESC;

-- 6-5. 모델별 판매 가능 재고와 판매율 (LEFT JOIN + 윈도우 순위)
--      판매 가능 재고 = 제조된 정상품 중 아직 주문되지 않은 대수
WITH stock AS (
  SELECT m.model_name,
         SUM(m.is_defective = 0)                                   AS good_qty,
         SUM(o.serial_no IS NOT NULL)                              AS sold_qty,
         SUM(m.is_defective = 0 AND o.serial_no IS NULL)           AS available_qty
  FROM manufacture m
  LEFT JOIN orders o ON o.serial_no = m.serial_no
  GROUP BY m.model_name
)
SELECT p.category, s.model_name, p.product_name,
       s.good_qty, s.sold_qty, s.available_qty,
       ROUND(s.sold_qty / s.good_qty * 100, 1) AS sell_through_pct,
       RANK() OVER (PARTITION BY p.category ORDER BY s.available_qty DESC) AS overstock_rank
FROM stock s
JOIN product p ON p.model_name = s.model_name
ORDER BY p.category, overstock_rank;

-- 6-6. 직업군별 구매 현황과 객단가 (집계 + 전체 대비 비중)
WITH by_job AS (
  SELECT c.job,
         COUNT(DISTINCT c.customer_id) AS buyers,
         COUNT(*)     AS orders_cnt,
         SUM(p.price) AS revenue
  FROM orders o
  JOIN customer c ON c.customer_id = o.customer_id
  JOIN product  p ON p.model_name  = o.model_name
  GROUP BY c.job
)
SELECT job, buyers, orders_cnt, revenue,
       ROUND(revenue / orders_cnt) AS avg_order_value,
       ROUND(revenue / SUM(revenue) OVER () * 100, 1) AS revenue_share_pct
FROM by_job
ORDER BY revenue DESC;
