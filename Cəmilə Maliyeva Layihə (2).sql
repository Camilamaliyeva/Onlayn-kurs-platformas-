-- 1. KATALOQUN VƏZİYYƏTİ
-- Direktor investor görüşünə hazırlaşır: "Hər kateqoriyada neçə AKTİV
-- kursumuz var və orta qiymət nə qədərdir? Bütün kateqoriyalar siyahıda
-- qalsın, aktiv kursu olmayan kateqoriya da görünsün."
-- Sıralama: kurs sayı azalan.
-- Nəticə: category_id, category_name, course_count, avg_price
select
cat.category_id,
cat.category_name,
count(c.course_id) course_count,
round(nvl(avg(c.price),0),2) avg_price
from category cat left join course c
on cat.category_id=c.category_id and c.status='Active'
group by cat.category_id,cat.category_name
order by course_count desc;

-- 2. PUL AXINI
-- Maliyyə direktoru qrafik çəkmək istəyir: "Son 12 ayda hər ay neçə ödəniş
-- daxil olub və ümumi məbləğ nə qədərdir? Aylar artan sırada."
-- Nəticə: month_text, payment_count, total_amount
select
to_char(payment_date,'YYYY-MM') month_text,
count(payment_id) payment_count,
round(sum(amount),2) total_amount
from payment
where payment_date >= add_months(trunc(sysdate),-12)
group by to_char(payment_date,'YYYY-MM')
order by month_text asc;

-- 3. MÜƏLLİMLƏRİN REYTİNQİ (PUL İLƏ)
-- Direktor müəllimlərin bonusunu hesablayır: "Hər müəllimin neçə kursu var
-- və onun kursları platformaya ümumilikdə nə qədər pul gətirib? BÜTÜN
-- müəllimlər siyahıda olsun yeni işə götürdüyümüz, hələ kursu olmayan
-- müəllim də 0 ilə görünsün."
-- Sıralama: gəlir azalan.
-- Nəticə: instructor_id, first_name, last_name, course_count, total_revenue
select
i.instructor_id,
i.first_name,
i.last_name,
count(distinct c.course_id) course_count,
round(nvl(sum(p.amount),0),2) total_revenue
from instructor i left join course c
on i.instructor_id=c.instructor_id
left join enrollment e 
on c.course_id=e.course_id
left join payment p 
on e.enrollment_id=p.enrollment_id
group by i.instructor_id, i.first_name, i.last_name
order by total_revenue desc;

-- 4. ÖLÜ KURSLAR
-- Məhsul meneceri: "Elə kurslar var ki, sayta qoymuşuq, amma bir nəfər də
-- yazılmayıb. Onları kataloqdan çıxarmaq istəyirəm, siyahını ver."
-- Nəticə: course_id, course_title, category_name, price
select
c.course_id,
c.course_title,
cat.category_name,
c.price
from course c join category cat
on c.category_id=cat.category_id
left join enrollment e 
on c.course_id=e.course_id
where e.enrollment_id is null;

-- 5. TAMAMLANMA PROBLEMİ
-- Direktor narahatdır: "Tələbələr kursları bitirmir. Ən azı 3 qeydiyyatı
-- olan hər kurs üçün qeydiyyat sayını, tamamlayanların sayını və
-- tamamlanma faizini göstər. Ləğv edilmiş (CANCELLED) qeydiyyatlar
-- ümumiyyətlə sayılmasın."
-- completion_rate = tamamlayan / ümumi * 100
-- Sıralama: faiz azalan.
-- Nəticə: course_id, course_title, enrollment_count, completed_count, completion_rate
select
c.course_id,
c.course_title,
count(e.enrollment_id) enrollment_count,
count(
    case when e.status='Completed' then 1 
    end) completed_count,
round(count(
    case when e.status='Completed' then 1
    end)*100/count(e.enrollment_id),2) completion_rate
from course c join enrollment e
on c.course_id=e.course_id
where e.status <> 'CANCELLED'
group by c.course_id, c.course_title
having count(e.enrollment_id) >= 3
order by completion_rate desc;

-- 6. BORCLULAR (I HİSSƏ)
-- Mühasibat şöbəsi zəng edir: "Elə qeydiyyatlar var ki, tələbə kursa
-- yazılıb, amma heç bir ödəniş etməyib. Kimlərdir?"
-- Nəticə: enrollment_id, student_id, first_name, last_name, course_title,
--         enroll_date, price
select
e.enrollment_id,
s.student_id,
s.first_name,
s.last_name,
c.course_title,
e.enroll_date,
c.price
from enrollment e join student s
on e.student_id=s.student_id
join course c
on e.course_id=c.course_id
left join payment p
on e.enrollment_id=p.enrollment_id
where p.payment_id is null;

-- 7. BORCLULAR (II HİSSƏ)
-- Mühasib davam edir: "İndi də hissə-hissə ödəyib yarımçıq qoyanları tap.
-- Yəni ödədiyi ümumi məbləğ kursun qiymətindən azdır."
-- Sıralama: borc azalan.
-- Nəticə: enrollment_id, student_id, course_title, price, paid_amount, debt
select
e.enrollment_id,
s.student_id,
c.course_title,
c.price,
round(sum(p.amount),2) paid_amount,
round(c.price - sum(p.amount),2) debt
from enrollment e join student s
on e.student_id=s.student_id
join course c 
on e.course_id=c.course_id
join payment p
on e.enrollment_id=p.enrollment_id
group by e.enrollment_id, s.student_id, c.course_title, c.price
having sum(p.amount) < c.price
order by debt desc;

-- 8. ƏN BÖYÜK ÖDƏNİŞLƏR
-- Marketinq şöbəsi VIP kampaniya hazırlayır: "Hər tələbənin son 1 ildə
-- etdiyi ən böyük ödənişi göstər - tələbə başına yalnız 1 sətir olsun."
-- Bərabərlik: eyni məbləğ varsa tarixi daha yeni olan seçilsin.
-- Sıralama: məbləğ azalan.
-- Nəticə: student_id, first_name, last_name, payment_id, payment_date, amount
with rankedPayments as(
            select
            s.student_id,
            s.first_name,
            s.last_name,
            p.payment_id,
            p.payment_date,
            p.amount,
            row_number() over( partition by s.student_id
                order by p.amount desc, p.payment_date desc
                    ) rn
            from student s join enrollment e
            on s.student_id=e.student_id
            join payment p
            on e.enrollment_id=p.enrollment_id
            where p.payment_date >= add_months(trunc(sysdate),-12)
            )
select
student_id,
first_name,
last_name,
payment_id,
payment_date,
amount
from rankedPayments
where rn=1
order by amount desc;

-- 9. HƏR KATEQORİYANIN LOKOMOTİVİ
-- Direktor reklam büdcəsini bölür: "Hər kateqoriyada ən çox pul gətirən
-- kursu göstər - kateqoriya başına 1 sətir."
-- Bərabərlik: eyni məbləğ varsa course_id kiçik olan seçilsin.
-- Sıralama: gəlir azalan.
-- Nəticə: category_id, category_name, course_id, course_title, total_revenue
with CourseRevenue as (
        select
        cat.category_id,
        cat.category_name,
        c.course_id,
        c.course_title,
        round(sum(p.amount),2) total_revenue,
        row_number() over(partition by cat.category_id
                     order by sum(p.amount) desc, c.course_id asc
                     ) rn
        from category cat join course c 
        on cat.category_id=c.category_id
        join enrollment e 
        on c.course_id=e.course_id
        join payment p
        on e.enrollment_id=p.enrollment_id
        group by cat.category_id, cat.category_name, c.course_id, c.course_title
        )
select
category_id,
category_name,
course_id,
course_title,
total_revenue
from CourseRevenue
where rn=1
order by total_revenue desc;

-- 10. ƏN SADİQ TƏLƏBƏ
-- CRM komandası hədiyyə göndərmək istəyir: "Ən çox kursa yazılmış tələbəni
-- tap. Eyni sayda kursu olan bir neçə tələbə varsa hamısı göstərilsin."
-- Nəticə: student_id, first_name, last_name, enrollment_count
with StudentEnrollments as (
            select
            s.student_id,
            s.first_name,
            s.last_name,
            count(e.enrollment_id) enrollment_count,
            dense_rank() over ( order by count (e.enrollment_id) desc) rnk
            from student s join enrollment e
            on s.student_id=e.student_id
            group by s.student_id, s.first_name, s.last_name
                )
select
student_id,
first_name,
last_name,
enrollment_count
from StudentEnrollments
where rnk=1;

-- 11. AYIN BESTSELLERİ
-- Marketinq şöbəsi aylıq hesabat hazırlayır: "Son 6 ayda hər ay ən çox
-- qeydiyyat alan kursu göstər - hər ay üçün 1 sətir."
-- Bərabərlik: eyni sayda qeydiyyat varsa course_id kiçik olanı götür.
-- Sıralama: ay artan.
-- Nəticə: month_text, course_id, course_title, enrollment_count
with MonthlyCourseEnrollments as (
            select
            to_char(e.enroll_date, 'YYYY-MM') month_text,
            c.course_id,
            c.course_title,
            count(e.enrollment_id) enrollment_count,
            row_number() over ( partition by to_char(e.enroll_date,'YYYY-MM')
            order by count(e.enrollment_id) desc, c.course_id asc
                ) rn
            from enrollment e join course c
            on e.course_id=c.course_id
            where e.enroll_date >= add_months(trunc(sysdate),-6)
            group by to_char(e.enroll_date,'YYYY-MM'),c.course_id,c.course_title
            )
select
month_text,
course_id,
course_title,
enrollment_count
from MonthlyCourseEnrollments
where rn=1
order by month_text asc;

-- 12. RƏYLƏR
-- Məhsul meneceri sayta "Ən yaxşı kurslar" bölməsi əlavə edir: "Ən azı 3
-- rəyi olan kursların orta reytinqini göstər."
-- Sıralama: orta reytinq azalan, sonra rəy sayı azalan.
-- Nəticə: course_id, course_title, review_count, avg_rating
select
c.course_id,
c.course_title,
count(r.review_id) review_count,
round(avg(r.rating),2)avg_rating
from course c join enrollment e
on c.course_id=e.course_id
join review r
on e.enrollment_id=r.enrollment_id
group by c.course_id, c.course_title
having count(r.review_id) >= 3
order by avg_rating desc, review_count desc;

-- 13. ORTADAN YUXARI
-- Direktor: "Mənə platformanın ümumi orta reytinqindən yüksək olan
-- kursları göstər. Ümumi ortanı əl ilə yazma, sorğunun içində hesabla."
-- Sıralama: orta reytinq azalan.
-- Nəticə: course_id, course_title, avg_rating
with CourseRatings as (
            select
            c.course_id,
            c.course_title,
            round(avg(r.rating),2) avg_rating
            from course c join enrollment e
            on c.course_id=e.course_id
            join review r 
            on e.enrollment_id=r.enrollment_id
            group by c.course_id, c.course_title
    ),
GlobalAverage as (
            select 
            avg(rating) global_avg
            from review 
    )
select
cr.course_id,
cr.course_title,
cr.avg_rating
from CourseRatings cr, GlobalAverage ga
where cr.avg_rating > ga.global_avg
order by cr.avg_rating desc;

-- 14. AUDİTORİYA PORTRETİ
-- Marketinq şöbəsi reklam hədəfini dəqiqləşdirir: "Tələbələri yaş qruplarına
-- böl və hər qrupda neçə tələbə olduğunu, həmçinin orta ödəniş məbləğini
-- göstər. Heç ödəniş etməmiş tələbə də qrupda sayılsın (0 ilə)."
-- Yaş qrupları: '25 və aşağı', '26-35', '36 və yuxarı'
-- Nəticə: age_group, student_count, avg_paid
with StudentAgePayments as (
            select
            s.student_id,
            case
                when floor(months_between(trunc(sysdate),s.birth_date)/12) <= 25 then '25 və aşağı'
                when floor(months_between(trunc(sysdate),s.birth_date)/12) between 26 and 35 then '26-35'
                else '36 və yuxarı'
                end age_group,
                nvl(sum(p.amount),0) total_student_payment, --Ödəniş edib-etmədiyini yoxlamaq üçün
                count(p.payment_id) payment_count
                from student s left join enrollment e
                on s.student_id=e.student_id
                left join payment p
                on e.enrollment_id=p.enrollment_id
                group by s.student_id, s.birth_date
         )
select 
age_group,
count(student_id) student_count,
round(avg(total_student_payment),2) avg_paid
from StudentAgePayments
group by age_group
order by age_group asc;

-- 15. YUXUYA GEDƏNLƏR
-- Satış komandası zəng siyahısı istəyir: "Aktiv qeydiyyatı olan, amma son
-- 3 ayda HEÇ BİR ödəniş etməmiş tələbələri tap."
-- Nəticə: student_id, first_name, last_name, active_enrollment_count
select
s.student_id,
s.first_name,
s.last_name,
count(e.enrollment_id) active_enrollment_count
from student s join enrollment e
on s.student_id=e.student_id
where e.status='ACTIVE' and s.student_id not in (
                                        select
                                        distinct en.student_id
                                        from enrollment en join payment p
                                        on en.enrollment_id=p.enrollment_id
                                        where p.payment_date >= add_months(trunc(sysdate),-3)
                                        )
group by s.student_id, s.first_name, s.last_name;

-- 16. MÜƏLLİMİN ƏN YAXŞI KURSU
-- İl sonu mükafatı üçün: "Hər müəllimin ən yüksək orta reytinqli kursunu
-- göstər - müəllim başına 1 sətir. Heç rəyi olmayan müəllim siyahıda
-- olmaya bilər."
-- Bərabərlik: eyni orta reytinq varsa rəy sayı çox olan kurs seçilsin.
-- Sıralama: orta reytinq azalan.
-- Nəticə: instructor_id, first_name, last_name, course_id, course_title,
--         avg_rating, review_count
with InstructorCourseRatings as (
        select
        i.instructor_id,
        i.first_name,
        i.last_name,
        c.course_id,
        c.course_title,
        round(avg(r.rating),2) avg_rating,
        count(r.review_id) review_count,
        row_number() over ( partition by i.instructor_id
        order by avg(r.rating) desc,count(r.review_id) desc
        ) rn
        from instructor i join course c
        on i.instructor_id=c.instructor_id
        join enrollment e
        on c.course_id=e.course_id
        join review r
        on e.enrollment_id=r.enrollment_id
        group by i.instructor_id, i.first_name, i.last_name, c.course_id, c.course_title
        )
select
instructor_id,
first_name,
last_name,
course_id,
course_title,
avg_rating,
review_count
from InstructorCourseRatings
where rn=1
order by avg_rating desc;

            
        



    
