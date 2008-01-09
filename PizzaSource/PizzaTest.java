/*

Test cases for the Pizza package.

Written by Matthew Sachs, 2006-03-08, for a lecture on unit testing
in Brandeis University's COSI 22a.  Source and lecture notes are released
into the public domain.  c.f. http://www.zevils.com/writings/unit-testing/

*/


import java.util.*;
import Pizza.*;

public class PizzaTest {
	//report(String, boolean) from sample test classes written by Kenroy
	//Granville and Tim Hickey for CS22a assignments.
	//
	public void report(String s, boolean b) {
		System.out.println("  "+s+" - "+(b ? "Succeeded!" : " Failed!"));
	}

	//Make sure that we get an error if we don't initialize the toppings
	//list.  This must be called before anything else which uses Pizza.
	public void mustSetToppings() throws Exception {
		if(Pizza.AllToppings() != null) {
			//We were called too late.
			throw new Exception("mustSetToppings was called, but thte Toppings were already set!");
		}

		boolean exceptionThrown = false;
		try {
			Pizza p = new Pizza();
		} catch(MustSetToppingsException e) {
			exceptionThrown = true;
		}
		report("mustSetToppings thrown", exceptionThrown);
	}

	//Test topping methods
	public void toppings() {
		Topping t = new Topping("foo", Topping.CHEESE);
		report("name getter", t.name().equals("foo"));
		report("type getter", t.type() == Topping.CHEESE);

		Topping t1 = new Topping("foo", Topping.CHEESE);

		//Make sure it does the right thing when comparing strings
		Topping t2 = new Topping(new String("foo"), Topping.CHEESE);

		Topping t3 = new Topping("foo", Topping.MEAT);
		Topping t4 = new Topping("bar", Topping.CHEESE);
		Topping t5 = new Topping("bar", Topping.MEAT);

		report("basic Topping inequality", !t1.equals(t5));
		report("basic Topping equality", t1.equals(t2));
		report("names equal, types different", !t1.equals(t3));
		report("names different, types equal", !t1.equals(t4));
	}

	//Test ToppingConstraint methods
	public void toppingConstraintGetters() {
		Topping t1 = new Topping(null, Topping.NOTYPE);
		Topping t2 = new Topping("foo", Topping.CHEESE);
		ToppingConstraint c1 = new ToppingConstraint(true, true, t1);
		ToppingConstraint c2 = new ToppingConstraint(false, false, t2);

		report("isNegative getter 1", c1.isNegative());
		report("isNegative getter 2", !c2.isNegative());
		report("isMandatory getter 1", c1.isMandatory());
		report("isMandatory getter 2", !c2.isMandatory());
		report("topping getter 1", c1.topping().equals(t1));
		report("topping getter 2", c2.topping().equals(t2));

		report("ToppingConstraint isEqual basic negative",
			!c1.equals(c2));

		ToppingConstraint c = new ToppingConstraint(false, false, t2);
		report("ToppingConstraint isEqual basic positive",
			c2.equals(c));

		c = new ToppingConstraint(true, false, t2);
		report("ToppingConstraint isEqual negative negative",
			!c2.equals(c));

		c = new ToppingConstraint(false, true, t2);
		report("ToppingConstraint isEqual negative mandatory",
			!c2.equals(c));

		c = new ToppingConstraint(false, false, t1);
		report("ToppingConstraint isEqual negative topping",
			!c2.equals(c));
	}

	//Setting the list of Toppings should return an identical list.
	//This must be called after mustSetToppings and before anything else
	//that uses Pizza.
	public void setAllToppings() throws MustSetToppingsException {
		Topping mozarella = new Topping("mozarella", Topping.CHEESE);
		Topping pepperoni = new Topping("pepperoni", Topping.MEAT);
		Topping[] setToppings = {mozarella, pepperoni};
		Pizza.setAllToppings(setToppings);
		Topping[] getToppings = Pizza.AllToppings();

		report("setAllToppings length matches",
			setToppings.length == getToppings.length);
		boolean ToppingsMatch = true;
		for(int i = 0;
		  (i < setToppings.length) &&
		  (i < getToppings.length); i++) {
			if(!getToppings[i].equals(setToppings[i])) {
				ToppingsMatch = false;
				break;
			}
		}
		report("setAllToppings Toppings match", ToppingsMatch);

		report("get nonexistant topping",
			Pizza.getTopping("pickles") == null);
		Topping t = Pizza.getTopping("pepperoni");
		report("get existant topping",
			(t != null) && t.equals(pepperoni));
	}

	public void addConstraint() throws MustSetToppingsException {
		//Technically, we shouldn't need to do this because
		//the setAllToppings test needs to be called first, and that
		//test will set the toppings.  However, by doing this here,
		//we make this test stand on its own and not depend on
		//any of the other tests, which makes our test suite more
		//robust.
		Topping[] allToppings = {new Topping("cheese", Topping.CHEESE)};
		Pizza.setAllToppings(allToppings);

		Pizza p = new Pizza();
		report("constraints starts empty", p.constraints().size() == 0);

		ToppingConstraint c = new ToppingConstraint(false, false,
			new Topping(null, Topping.NOTYPE));
		p.addConstraint(c);
		report("after adding, one constraint",
			p.constraints().size() == 1);

		report("correct constraint added", p.constraints().contains(c));
	}

	public void applyConstraints() throws MustSetToppingsException, ImpossiblePizzaException {
		//Again, we could get away with setting up the toppings in
		//one of the other tests, but this test is very sensitive
		//to the list of available toppings, so this keeps it nice
		//and stable.
		Topping mozarella = new Topping("mozarella", Topping.CHEESE);
		Topping ricotta = new Topping("ricotta", Topping.CHEESE);
		Topping pepperoni = new Topping("pepperoni", Topping.MEAT);
		Topping pineapple = new Topping("pineapple", Topping.VEGGIE);
		Topping allToppings[] = {mozarella, ricotta, pepperoni, pineapple};
		Pizza.setAllToppings(allToppings);

		Pizza p = new Pizza();

		//Do simple, unconstrained cases work?
		report("unconstrained minimal",
			p.toppingsMinimal().size() == 0);
		report("unconstrained maximal",
			p.toppingsMaximal().size() ==
			  Pizza.AllToppings().length);
		report("unconstrained targetted", p.toppings(2).size() == 2);


		//Alright, now let's test mandatory constraints.

		ToppingConstraint mustHaveMozarella =
			new ToppingConstraint(false, true, mozarella);
		ToppingConstraint mustNotHavePepperoni =
			new ToppingConstraint(true, true, pepperoni);

		p.addConstraint(mustHaveMozarella);
		Set s = p.toppingsMinimal();
		report("positive constraint minimal",
			(s.size() == 1) && s.contains(mozarella));

		//Minimal pizza should have only positive mandatories.
		//Maximal pizza should have all but negative mandatories.
		//These tests test the one-constraint case.
		//
		p = new Pizza();
		p.addConstraint(mustNotHavePepperoni);
		s = p.toppingsMaximal();
		report("negative constraint maximal",
			(s.size() == Pizza.AllToppings().length - 1) &&
			!s.contains(pepperoni));

		//Okay, what about two constraints?
		//Note that we test the one-constraint and two-constraint
		//cases separately.  Now, if the two-constraint cases work,
		//probably the one-constraint cases have to work too, so do
		//we really need to test those separately?  It probably isn't
		//buying us any extra coverage to do so, but it will help us
		//isolate failures.  By testing both, it narrow what we need
		//to look at if the two-constraint tests fail.
		//
		p.addConstraint(mustHaveMozarella);
		s = p.toppingsMinimal();
		report("dual constraint minimal",
			(s.size() == 1) && s.contains(mozarella));
		s = p.toppingsMaximal();
		report("dual constraint maximal",
			(s.size() == Pizza.AllToppings().length - 1) &&
			!s.contains(pepperoni));


		//Okay, now let's try some optional constraints.

		ToppingConstraint preferRicotta =
			new ToppingConstraint(false, false, ricotta);
		p = new Pizza();
		p.addConstraint(preferRicotta);

		//Minimal pizza with no mandatories should have no toppings.
		s = p.toppingsMinimal();
		report("optional constraint minimal", s.size() == 0);

		//But asking for a topping or two should give us toppings.
		//A one-topping pizza should give it the thing we told it
		//we prefer.  For a two-topping pizza, it doesn't matter
		//what the second topping is, we have no more preferences.
		//
		s = p.toppings(1);
		report("optional constraint 1",
			(s.size() == 1) && s.contains(ricotta));
		s = p.toppings(2);
		report("optional constraint expansion", s.size() == 2);

		//What about preferences for a *type* of topping?
		//
		ToppingConstraint preferCheese = new ToppingConstraint(false, false, new Topping(null, Topping.CHEESE));
		p = new Pizza();
		p.addConstraint(preferCheese);
		s = p.toppings(1);
		report("type constraint",
			(s.size() == 1) &&
			(((Topping)s.iterator().next()).type() == Topping.CHEESE));

		//If we have multiple preferences, make sure we pick the
		//toppings which satisfy the most.  So if we want cheese,
		//and we want ricotta, and we want pepperoni, a one-topping
		//pizza should have ricotta, not pepperoni.
		//
		p.addConstraint(preferRicotta);
		ToppingConstraint preferPepperoni = new ToppingConstraint(false, false, pepperoni);
		s = p.toppings(1);
		report("preference scoring",
			(s.size() == 1) && s.contains(ricotta));

		//This scoring applies to mandatory constraints too.
		//If we both need cheese and need mozarella, a one-topping
		//pizza should just have mozarella, not both mozarella and
		//ricotta.  We also test the "both need cheese and need
		//mozarella" case, just in case we happened to get lucky.
		//
		ToppingConstraint mustHaveRicotta = new ToppingConstraint(false, true, ricotta);
		ToppingConstraint mustHaveCheese = new ToppingConstraint(false, true, new Topping(null, Topping.CHEESE));
		p = new Pizza();
		p.addConstraint(mustHaveCheese);
		p.addConstraint(mustHaveMozarella);
		s = p.toppings(1);
		report("mandatory constraint scoring 1",
			(s.size() == 1) && s.contains(mozarella));
		p = new Pizza();
		p.addConstraint(mustHaveCheese);
		p.addConstraint(mustHaveRicotta);
		s = p.toppings(1);
		report("mandatory constraint scoring 2",
			(s.size() == 1) && s.contains(ricotta));

		//Make sure negative constraints work.  If someone wants
		//ricotta and someone wants pepperoni, but someone else
		//doesn't want cheese, a one-topping pizza should have
		//pepperoni, not ricotta.
		//
		p = new Pizza();
		p.addConstraint(preferRicotta);
		p.addConstraint(preferPepperoni);
		ToppingConstraint preferNoCheese =
			new ToppingConstraint(true, false,
			   new Topping(null, Topping.CHEESE));
		p.addConstraint(preferNoCheese);
		s = p.toppings(1);
		report("negative constraints",
			(s.size() == 1) && s.contains(pepperoni));

		//Make sure we throw an error if someone asks for an
		//impossible pizza, e.g. one which both has ricotta and
		//does not have ricotta.
		//
		p = new Pizza();
		p.addConstraint(mustHaveRicotta);
		ToppingConstraint mustNotHaveRicotta = new ToppingConstraint(true, true, ricotta);
		p.addConstraint(mustNotHaveRicotta);
		boolean threwException = false;
		try {
			p.toppingsMinimal();
		} catch(ImpossiblePizzaException e) {
			threwException = true;
		}
		report("impossible pizza", threwException);
	}

	public static void main(String[] args) throws Exception {
		PizzaTest pt = new PizzaTest();
		pt.mustSetToppings();
		pt.toppings();
		pt.toppingConstraintGetters();
		pt.setAllToppings();
		pt.addConstraint();
		pt.applyConstraints();
	}
}
